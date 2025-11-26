#!/bin/bash
# PSplash 이미지 생성 스크립트
# 사용법: ./create_splash.sh input_image.png output_header.h

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <input_png> <output_header>"
    echo "Example: $0 splash.png psplash-poky-img.h"
    exit 1
fi

INPUT_PNG="$1"
OUTPUT_HEADER="$2"

if [ ! -f "$INPUT_PNG" ]; then
    echo "Error: Input file $INPUT_PNG not found"
    exit 1
fi

# PSplash 이미지 요구사항:
# - 권장 크기: 800x480 (라즈베리파이 HDMI 해상도에 맞게)
# - PNG 형식
# - RGB 컬러

echo "Converting $INPUT_PNG to PSplash header format..."

# ImageMagick으로 이미지 정보 추출
WIDTH=$(identify -format "%w" "$INPUT_PNG")
HEIGHT=$(identify -format "%h" "$INPUT_PNG")

echo "Image dimensions: ${WIDTH}x${HEIGHT}"

# PSplash 헤더 생성 (기본 템플릿)
cat > "$OUTPUT_HEADER" << 'HEADER_EOF'
/* GdkPixbuf RGB C-Source image dump 1-byte-run-length-encoded */

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include "psplash.h"

static guint8 const header_data_pixel_data[] = {
HEADER_EOF

# PNG를 PPM으로 변환 후 16진수로 변환
convert "$INPUT_PNG" -resize 1024x600! -depth 8 ppm:- | \
    tail -n +4 | \
    xxd -i >> "$OUTPUT_HEADER"

# 헤더 마무리
cat >> "$OUTPUT_HEADER" << 'FOOTER_EOF'
};

static GdkPixdata const header_data_pixdata = {
  0x47646b50,
  24,
  0x2010001,
  96,
  1024,
  600,
  header_data_pixel_data
};
FOOTER_EOF

echo "PSplash header generated: $OUTPUT_HEADER"
echo ""
echo "Next steps:"
echo "1. Copy $OUTPUT_HEADER to meta-custom/meta-env/recipes-core/psplash/psplash/"
echo "2. Rebuild the image: bitbake des-image"
