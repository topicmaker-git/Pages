#!/bin/sh
# 使い方: sh make_real_audio_zip.sh <実mp3のあるディレクトリ>
# s*_*.mp3 を id*_*.mp3 にコピーして audio.zip を作る
SRC="$1"; T=$(mktemp -d) || exit 1
cp "$SRC/s1_a0.mp3" "$T/id001_a0.mp3" || exit 1
cp "$SRC/s1_b0.mp3" "$T/id001_b0.mp3" || exit 1
cp "$SRC/s1_a1.mp3" "$T/id001_a1.mp3" || exit 1
cp "$SRC/s1_b1.mp3" "$T/id001_b1.mp3" || exit 1
cp "$SRC/s1_a2.mp3" "$T/id001_a2.mp3" || exit 1
cp "$SRC/s1_b2.mp3" "$T/id001_b2.mp3" || exit 1
cp "$SRC/s2_a0.mp3" "$T/id002_a0.mp3" || exit 1
cp "$SRC/s2_b0.mp3" "$T/id002_b0.mp3" || exit 1
cp "$SRC/s2_a1.mp3" "$T/id002_a1.mp3" || exit 1
cp "$SRC/s2_b1.mp3" "$T/id002_b1.mp3" || exit 1
cp "$SRC/s2_a2.mp3" "$T/id002_a2.mp3" || exit 1
cp "$SRC/s2_b2.mp3" "$T/id002_b2.mp3" || exit 1
cp "$SRC/s3_a0.mp3" "$T/id003_a0.mp3" || exit 1
cp "$SRC/s3_b0.mp3" "$T/id003_b0.mp3" || exit 1
cp "$SRC/s3_a1.mp3" "$T/id003_a1.mp3" || exit 1
cp "$SRC/s3_b1.mp3" "$T/id003_b1.mp3" || exit 1
cp "$SRC/s3_a2.mp3" "$T/id003_a2.mp3" || exit 1
cp "$SRC/s3_b2.mp3" "$T/id003_b2.mp3" || exit 1
cp "$SRC/s4_a0.mp3" "$T/id004_a0.mp3" || exit 1
cp "$SRC/s4_b0.mp3" "$T/id004_b0.mp3" || exit 1
cp "$SRC/s4_a1.mp3" "$T/id004_a1.mp3" || exit 1
cp "$SRC/s4_b1.mp3" "$T/id004_b1.mp3" || exit 1
cp "$SRC/s4_a2.mp3" "$T/id004_a2.mp3" || exit 1
cp "$SRC/s4_b2.mp3" "$T/id004_b2.mp3" || exit 1
cp "$SRC/s5_a0.mp3" "$T/id005_a0.mp3" || exit 1
cp "$SRC/s5_b0.mp3" "$T/id005_b0.mp3" || exit 1
cp "$SRC/s5_a1.mp3" "$T/id005_a1.mp3" || exit 1
cp "$SRC/s5_b1.mp3" "$T/id005_b1.mp3" || exit 1
cp "$SRC/s5_a2.mp3" "$T/id005_a2.mp3" || exit 1
cp "$SRC/s5_b2.mp3" "$T/id005_b2.mp3" || exit 1
(cd "$T" && zip -X -q audio.zip id*.mp3) && mv "$T/audio.zip" ./audio.zip
rm -rf "$T"; echo "audio.zip written ($(unzip -l audio.zip | tail -1))"
