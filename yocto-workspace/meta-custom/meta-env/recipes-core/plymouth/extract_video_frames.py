#!/usr/bin/env python3
"""
Extract video frames for Plymouth boot animation
Converts MP4 to PNG frame sequence at 30fps with target resolution
"""

import cv2
import os
import sys

def extract_frames(video_path, output_dir, target_fps=30, target_width=1024, target_height=600):
    """Extract frames from video at specified FPS and resolution"""

    # Create output directory
    os.makedirs(output_dir, exist_ok=True)

    # Open video
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        print(f"Error: Cannot open video {video_path}")
        return False

    # Get video properties
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    fps = cap.get(cv2.CAP_PROP_FPS)
    duration = total_frames / fps
    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))

    print(f"Video info:")
    print(f"  Original Resolution: {width}x{height}")
    print(f"  Target Resolution: {target_width}x{target_height}")
    print(f"  FPS: {fps}")
    print(f"  Duration: {duration:.2f}s")
    print(f"  Total frames: {total_frames}")
    print()

    # Calculate frame interval to achieve target FPS
    frame_interval = max(1, int(fps / target_fps))
    output_frame_count = int(total_frames / frame_interval)

    print(f"Extracting at {target_fps} FPS:")
    print(f"  Frame interval: every {frame_interval} frame(s)")
    print(f"  Output frames: {output_frame_count}")
    print()

    # Extract frames
    frame_num = 0
    output_num = 0

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        # Save frame at specified interval
        if frame_num % frame_interval == 0:
            # Resize frame to target resolution
            resized_frame = cv2.resize(frame, (target_width, target_height),
                                      interpolation=cv2.INTER_LANCZOS4)

            output_path = os.path.join(output_dir, f"frame_{output_num:04d}.png")
            cv2.imwrite(output_path, resized_frame, [cv2.IMWRITE_PNG_COMPRESSION, 6])

            if output_num % 10 == 0:
                print(f"  Extracted frame {output_num}/{output_frame_count}")

            output_num += 1

        frame_num += 1

    cap.release()

    print(f"\nDone! Extracted {output_num} frames to {output_dir}")
    print(f"Resolution: {target_width}x{target_height}")
    return True

if __name__ == "__main__":
    video_path = "/home/seame/DES_Head-Unit/yocto-workspace/meta-custom/meta-env/recipes-core/psplash/Ferrari_logo.mp4"
    output_dir = "/home/seame/DES_Head-Unit/yocto-workspace/meta-custom/meta-env/recipes-core/plymouth/plymouth/des-theme/frames"

    if not os.path.exists(video_path):
        print(f"Error: Video not found at {video_path}")
        sys.exit(1)

    # Extract at 1024x600 resolution for Raspberry Pi display
    # Use 20fps for balance between smoothness and loading speed
    success = extract_frames(video_path, output_dir, target_fps=20,
                            target_width=1024, target_height=600)
    sys.exit(0 if success else 1)
