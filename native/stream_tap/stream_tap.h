/*
 * kurumi stream tap: mpv stream_cb backing store.
 *
 * mpv の stream コールバック (別スレッドから呼ばれる) は pure Dart では
 * 実装できないため、ブロッキングする read だけを C で持つ。HTTP 取得と
 * EIT 解析は Dart 側 (HttpClient + data/ts) が担当し、届いたバイト列を
 * kurumi_tap_push() でリングに積む。mpv 側は read_fn でブロック読みする。
 *
 * 対応プラットフォーム: Linux / Android (pthread)、Windows (SRWLOCK +
 * CONDITION_VARIABLE)。同期プリミティブの差異は stream_tap.c 内で吸収し、
 * API は共通。
 */
#ifndef KURUMI_STREAM_TAP_H
#define KURUMI_STREAM_TAP_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct kurumi_tap kurumi_tap_t;

/* セッションを1つ作る。Dart が1参照を持つ。失敗時は NULL。 */
kurumi_tap_t *kurumi_tap_create(size_t capacity);

/* 参照を1つ足す / 離す。0になったら破棄される。スレッドセーフ。 */
void kurumi_tap_ref(kurumi_tap_t *tap);
void kurumi_tap_unref(kurumi_tap_t *tap);

/*
 * リングに積む。満杯時は受け付けた分だけ返し、残りは Dart 側で保持する
 * (Dart スレッドをブロックさせないため、ここでは待たない)。
 * eof/abort 済みなら 0 を返す。
 */
size_t kurumi_tap_push(kurumi_tap_t *tap, const uint8_t *data, size_t len);

/* 上流の正常終了。溜めを読み切った後の read は 0 (EOF) を返す。 */
void kurumi_tap_eof(kurumi_tap_t *tap);

/* 異常終了。ブロック中の read を起こし、以降の read は -1 を返す。 */
void kurumi_tap_abort(kurumi_tap_t *tap);

/*
 * mpv_stream_cb_open_ro_fn 互換。info の配置は mpv の
 * mpv_stream_cb_info と同一 (cookie, read, seek, size, close, cancel
 * の順) でなければならない。seek/size/cancel は NULL を入れる。
 *
 * URI は "kurumi-ts://<id>" (id は作成セッションの16進アドレス)。
 * 成功時は 0、URI 不正・セッション不明時は -13
 * (MPV_ERROR_LOADING_FAILED) を返す。
 */
struct kurumi_cb_info {
  void *cookie;
  int64_t (*read_fn)(void *cookie, char *buf, uint64_t nbytes);
  int64_t (*seek_fn)(void *cookie, int64_t offset);
  int64_t (*size_fn)(void *cookie);
  void (*close_fn)(void *cookie);
  void (*cancel_fn)(void *cookie);
};

int kurumi_stream_open(void *user_data, char *uri,
                       struct kurumi_cb_info *info);

#ifdef __cplusplus
}
#endif

#endif /* KURUMI_STREAM_TAP_H */
