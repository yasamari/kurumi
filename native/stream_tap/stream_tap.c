/*
 * kurumi stream tap の実装。設計は stream_tap.h を参照。
 *
 * ライフサイクル: 参照カウントで管理する。Dart が作成時に1参照を持ち、
 * mpv の open ごとに1参照が付く。Dart の close と mpv の close_fn で
 * 参照を離し、0 で破棄する。mpv のコア破棄時に close_fn が必ず呼ばれる
 * ため、Dart 側の close 後に mpv が読み続けても use-after-free しない。
 *
 * ロック順序: registry_mutex → tap->mutex の一方向のみ。逆順は取らない。
 */
#include "stream_tap.h"

#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
/* Windows (MSVC は C11 threads.h 未対応のため Win32 API 直書き)。
 * SRWLOCK は条件変数と組み合わせる場合のみ使い、再帰ロックはしない
 * (本ファイルの使い方では不要)。破棄は不要。 */
#include <windows.h>

typedef SRWLOCK kurumi_mutex_t;
typedef CONDITION_VARIABLE kurumi_cond_t;

#define KURUMI_MUTEX_INIT SRWLOCK_INIT

/* Win32 API に失敗概念はほぼ無いため常に 0 を返す。 */
static int kurumi_mutex_init(kurumi_mutex_t *m) {
  InitializeSRWLock(m);
  return 0;
}
static void kurumi_mutex_destroy(kurumi_mutex_t *m) { (void)m; }
static void kurumi_mutex_lock(kurumi_mutex_t *m) {
  AcquireSRWLockExclusive(m);
}
static void kurumi_mutex_unlock(kurumi_mutex_t *m) {
  ReleaseSRWLockExclusive(m);
}
static int kurumi_cond_init(kurumi_cond_t *c) {
  InitializeConditionVariable(c);
  return 0;
}
static void kurumi_cond_destroy(kurumi_cond_t *c) { (void)c; }
static void kurumi_cond_signal(kurumi_cond_t *c) { WakeConditionVariable(c); }
static void kurumi_cond_broadcast(kurumi_cond_t *c) {
  WakeAllConditionVariable(c);
}
static void kurumi_cond_wait(kurumi_cond_t *c, kurumi_mutex_t *m) {
  SleepConditionVariableSRW(c, m, INFINITE, 0);
}
#else
#include <pthread.h>

typedef pthread_mutex_t kurumi_mutex_t;
typedef pthread_cond_t kurumi_cond_t;

#define KURUMI_MUTEX_INIT PTHREAD_MUTEX_INITIALIZER

static int kurumi_mutex_init(kurumi_mutex_t *m) {
  return pthread_mutex_init(m, NULL);
}
static void kurumi_mutex_destroy(kurumi_mutex_t *m) {
  pthread_mutex_destroy(m);
}
static void kurumi_mutex_lock(kurumi_mutex_t *m) { pthread_mutex_lock(m); }
static void kurumi_mutex_unlock(kurumi_mutex_t *m) { pthread_mutex_unlock(m); }
static int kurumi_cond_init(kurumi_cond_t *c) {
  return pthread_cond_init(c, NULL);
}
static void kurumi_cond_destroy(kurumi_cond_t *c) { pthread_cond_destroy(c); }
static void kurumi_cond_signal(kurumi_cond_t *c) { pthread_cond_signal(c); }
static void kurumi_cond_broadcast(kurumi_cond_t *c) {
  pthread_cond_broadcast(c);
}
static void kurumi_cond_wait(kurumi_cond_t *c, kurumi_mutex_t *m) {
  pthread_cond_wait(c, m);
}
#endif

/* MPV_ERROR_LOADING_FAILED。struct に触れず返す定数。 */
#define KURUMI_MPV_ERROR_LOADING_FAILED (-13)

/* 同時セッション数の上限。通常は視聴画面の1つのみ。 */
#define KURUMI_TAP_MAX_SESSIONS 16

struct kurumi_tap {
  kurumi_mutex_t mutex;
  kurumi_cond_t cond;
  uint8_t *ring;
  size_t capacity;
  size_t head; /* 読み位置 */
  size_t count; /* 溜めバイト数 */
  int eof;
  int aborted;
  int refcount;
};

static kurumi_mutex_t registry_mutex = KURUMI_MUTEX_INIT;
static kurumi_tap_t *registry[KURUMI_TAP_MAX_SESSIONS];

static void registry_remove(kurumi_tap_t *tap) {
  kurumi_mutex_lock(&registry_mutex);
  for (int i = 0; i < KURUMI_TAP_MAX_SESSIONS; i++) {
    if (registry[i] == tap) {
      registry[i] = NULL;
      break;
    }
  }
  kurumi_mutex_unlock(&registry_mutex);
}

/* 呼び出し側は registry_mutex を保持していること。 */
static kurumi_tap_t *registry_lookup(uintptr_t id) {
  for (int i = 0; i < KURUMI_TAP_MAX_SESSIONS; i++) {
    if (registry[i] != NULL && (uintptr_t)registry[i] == id) {
      return registry[i];
    }
  }
  return NULL;
}

kurumi_tap_t *kurumi_tap_create(size_t capacity) {
  if (capacity == 0) {
    return NULL;
  }
  kurumi_tap_t *tap = (kurumi_tap_t *)calloc(1, sizeof(*tap));
  if (tap == NULL) {
    return NULL;
  }
  tap->ring = (uint8_t *)malloc(capacity);
  if (tap->ring == NULL) {
    free(tap);
    return NULL;
  }
  if (kurumi_mutex_init(&tap->mutex) != 0) {
    free(tap->ring);
    free(tap);
    return NULL;
  }
  if (kurumi_cond_init(&tap->cond) != 0) {
    kurumi_mutex_destroy(&tap->mutex);
    free(tap->ring);
    free(tap);
    return NULL;
  }
  tap->capacity = capacity;
  tap->refcount = 1;

  kurumi_mutex_lock(&registry_mutex);
  int slot = -1;
  for (int i = 0; i < KURUMI_TAP_MAX_SESSIONS; i++) {
    if (registry[i] == NULL) {
      slot = i;
      break;
    }
  }
  if (slot < 0) {
    kurumi_mutex_unlock(&registry_mutex);
    kurumi_cond_destroy(&tap->cond);
    kurumi_mutex_destroy(&tap->mutex);
    free(tap->ring);
    free(tap);
    return NULL;
  }
  registry[slot] = tap;
  kurumi_mutex_unlock(&registry_mutex);
  return tap;
}

void kurumi_tap_ref(kurumi_tap_t *tap) {
  if (tap == NULL) {
    return;
  }
  kurumi_mutex_lock(&tap->mutex);
  tap->refcount++;
  kurumi_mutex_unlock(&tap->mutex);
}

void kurumi_tap_unref(kurumi_tap_t *tap) {
  if (tap == NULL) {
    return;
  }
  kurumi_mutex_lock(&tap->mutex);
  tap->refcount--;
  int gone = tap->refcount <= 0;
  kurumi_mutex_unlock(&tap->mutex);
  if (!gone) {
    return;
  }
  registry_remove(tap);
  kurumi_cond_destroy(&tap->cond);
  kurumi_mutex_destroy(&tap->mutex);
  free(tap->ring);
  free(tap);
}

size_t kurumi_tap_push(kurumi_tap_t *tap, const uint8_t *data, size_t len) {
  if (tap == NULL || data == NULL || len == 0) {
    return 0;
  }
  kurumi_mutex_lock(&tap->mutex);
  if (tap->eof || tap->aborted) {
    kurumi_mutex_unlock(&tap->mutex);
    return 0;
  }
  size_t space = tap->capacity - tap->count;
  size_t n = len < space ? len : space;
  size_t first = tap->capacity - ((tap->head + tap->count) % tap->capacity);
  if (first > n) {
    first = n;
  }
  memcpy(tap->ring + ((tap->head + tap->count) % tap->capacity), data, first);
  memcpy(tap->ring, data + first, n - first);
  tap->count += n;
  if (n > 0) {
    kurumi_cond_signal(&tap->cond);
  }
  kurumi_mutex_unlock(&tap->mutex);
  return n;
}

void kurumi_tap_eof(kurumi_tap_t *tap) {
  if (tap == NULL) {
    return;
  }
  kurumi_mutex_lock(&tap->mutex);
  tap->eof = 1;
  kurumi_cond_broadcast(&tap->cond);
  kurumi_mutex_unlock(&tap->mutex);
}

void kurumi_tap_abort(kurumi_tap_t *tap) {
  if (tap == NULL) {
    return;
  }
  kurumi_mutex_lock(&tap->mutex);
  tap->aborted = 1;
  kurumi_cond_broadcast(&tap->cond);
  kurumi_mutex_unlock(&tap->mutex);
}

/* --- mpv stream コールバック (mpv 側スレッドから呼ばれる) --- */

static int64_t tap_read(void *cookie, char *buf, uint64_t nbytes) {
  kurumi_tap_t *tap = (kurumi_tap_t *)cookie;
  kurumi_mutex_lock(&tap->mutex);
  while (tap->count == 0 && !tap->eof && !tap->aborted) {
    kurumi_cond_wait(&tap->cond, &tap->mutex);
  }
  if (tap->aborted) {
    kurumi_mutex_unlock(&tap->mutex);
    return -1;
  }
  if (tap->count == 0) {
    /* eof かつ空っぽ = 正常終了。 */
    kurumi_mutex_unlock(&tap->mutex);
    return 0;
  }
  size_t n = nbytes < tap->count ? (size_t)nbytes : tap->count;
  size_t first = tap->capacity - tap->head;
  if (first > n) {
    first = n;
  }
  memcpy(buf, tap->ring + tap->head, first);
  memcpy(buf + first, tap->ring, n - first);
  tap->head = (tap->head + n) % tap->capacity;
  tap->count -= n;
  kurumi_cond_signal(&tap->cond);
  kurumi_mutex_unlock(&tap->mutex);
  return (int64_t)n;
}

static void tap_close(void *cookie) {
  kurumi_tap_unref((kurumi_tap_t *)cookie);
}

int kurumi_stream_open(void *user_data, char *uri,
                       struct kurumi_cb_info *info) {
  (void)user_data;
  if (uri == NULL || info == NULL) {
    return KURUMI_MPV_ERROR_LOADING_FAILED;
  }
  static const char prefix[] = "kurumi-ts://";
  size_t prefix_len = sizeof(prefix) - 1;
  if (strncmp(uri, prefix, prefix_len) != 0) {
    return KURUMI_MPV_ERROR_LOADING_FAILED;
  }
  /* id は作成セッションの16進アドレス (Dart の toRadixString(16) 形式)。
   * SCNxPTR ではなく strtoull で読む (MSVC の inttypes 対応が不安定なため)。
   * 16進数以外・空・0 は拒否する。 */
  const char *digits = uri + prefix_len;
  char *end = NULL;
  unsigned long long parsed = strtoull(digits, &end, 16);
  uintptr_t id = (uintptr_t)parsed;
  if (end == digits || *end != '\0' || id == 0 ||
      (unsigned long long)id != parsed) {
    return KURUMI_MPV_ERROR_LOADING_FAILED;
  }
  kurumi_mutex_lock(&registry_mutex);
  kurumi_tap_t *tap = registry_lookup(id);
  if (tap != NULL) {
    /* 参照カウントは tap の mutex で守る。順序は registry → tap のみ。 */
    kurumi_mutex_lock(&tap->mutex);
    tap->refcount++;
    kurumi_mutex_unlock(&tap->mutex);
  }
  kurumi_mutex_unlock(&registry_mutex);
  if (tap == NULL) {
    return KURUMI_MPV_ERROR_LOADING_FAILED;
  }
  info->cookie = tap;
  info->read_fn = tap_read;
  info->seek_fn = NULL;
  info->size_fn = NULL;
  info->close_fn = tap_close;
  info->cancel_fn = NULL;
  return 0;
}
