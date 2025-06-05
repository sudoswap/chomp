#!/usr/bin/env python3
"""
Script to analyze mini GIF files and extract frame data for compression.
"""

import os
from PIL import Image
import numpy as np
import json

def analyze_gif(gif_path):
    """Analyze a GIF file and extract first frame data."""
    print(f"\nAnalyzing: {gif_path}")

    try:
        with Image.open(gif_path) as img:
            # Only extract the first frame
            frame = img.convert('RGBA')
            frame_array = np.array(frame)

            print(f"  Dimensions: {frame_array.shape[:2]} (width x height)")

            # Collect all unique colors from first frame only
            pixels = frame_array.reshape(-1, 4)  # RGBA
            all_colors = set()
            for pixel in pixels:
                all_colors.add(tuple(pixel))

            print(f"  Unique colors: {len(all_colors)}")

            # Check if more than 16 colors
            if len(all_colors) > 16:
                print(f"  ⚠️  WARNING: More than 16 colors detected! ({len(all_colors)} colors)")
                print(f"      Consider reducing colors or using a different compression strategy.")

            # Calculate bits needed
            bits_needed = max(1, (len(all_colors) - 1).bit_length())
            print(f"  Bits needed per pixel: {bits_needed}")

            # Create color palette (sorted for consistency)
            palette = sorted(list(all_colors))
            color_to_index = {color: idx for idx, color in enumerate(palette)}

            # Convert frame to indexed format
            height, width = frame_array.shape[:2]
            indexed_frame = np.zeros((height, width), dtype=np.uint8)
            for y in range(height):
                for x in range(width):
                    color = tuple(frame_array[y, x])
                    indexed_frame[y, x] = color_to_index[color]

            return {
                'path': gif_path,
                'dimensions': frame_array.shape[:2],
                'frame_count': 1,  # Only processing first frame
                'unique_colors': len(all_colors),
                'bits_needed': bits_needed,
                'palette': palette,
                'indexed_frame': indexed_frame,
                'raw_frame': frame_array
            }

    except Exception as e:
        print(f"  Error: {e}")
        return None

def compress_to_uint256(indexed_frame, bits_per_pixel):
    """Convert indexed frame to compressed uint256 values using simple bit packing."""
    height, width = indexed_frame.shape

    # Pack pixels into bits
    bit_string = ""
    for y in range(height):
        for x in range(width):
            pixel_value = indexed_frame[y, x]
            bit_string += format(pixel_value, f'0{bits_per_pixel}b')

    # Split into 256-bit chunks (uint256)
    uint256_values = []
    for i in range(0, len(bit_string), 256):
        chunk = bit_string[i:i+256]
        # Pad with zeros if needed
        chunk = chunk.ljust(256, '0')
        # Convert to integer
        uint_value = int(chunk, 2)
        uint256_values.append(uint_value)

    return uint256_values

def main():
    """Main function to analyze all mini GIFs."""
    imgs_dir = "drool/imgs"
    mini_gifs = [f for f in os.listdir(imgs_dir) if f.endswith('_mini.gif')]

    # print(f"Found {len(mini_gifs)} mini GIF files:")
    # for gif in sorted(mini_gifs):
    #     print(f"  - {gif}")

    results = {}

    for gif_file in sorted(mini_gifs):
        gif_path = os.path.join(imgs_dir, gif_file)
        result = analyze_gif(gif_path)
        if result:
            # Compress frame to uint256 format
            compressed = compress_to_uint256(result['indexed_frame'], result['bits_needed'])

            # Prepare data for JSON serialization
            result_for_json = {
                'pixels': [int(val) for val in compressed]
            }
            mon_name = gif_file.replace("_mini.gif", "")
            results[mon_name] = result_for_json

    # Save results to JSON
    with open('python/gif_analysis.json', 'w') as f:
        json.dump(results, f, indent=2)

if __name__ == "__main__":
    main()