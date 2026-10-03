# stream tap の Android ビルド。C ソース本体はリポジトリ直下の
# native/stream_tap/ にあり、Linux と共有する。ここでは APK 同梱用の
# libkurumi_stream_tap.so を各 ABI 向けに作るだけ。
cmake_minimum_required(VERSION 3.22.1)

project("kurumi_stream_tap")

add_library(
  kurumi_stream_tap
  SHARED
  ../../../../../native/stream_tap/stream_tap.c)

target_compile_options(kurumi_stream_tap PRIVATE -Wall -Wextra)

# pthread は NDK の libc に含まれるため明示リンクは不要。
# Android ログ等は使わず、無音 (エラーは戻り値で返す) にしている。
