#!/usr/bin/env python3
"""
Create custom UI bitmaps for WiX installer from kamiwaza logo design
"""

from PIL import Image, ImageDraw, ImageFont
import os

def create_banner_bitmap():
    """Create banner bitmap (493x58 pixels) with Kamiwaza logo design"""
    width, height = 493, 58
    img = Image.new('RGB', (width, height), (255, 255, 255))
    draw = ImageDraw.Draw(img)
    
    # Create teal background (matching the logo)
    teal_color = (0, 128, 128)  # Proper teal color
    draw.rectangle([0, 0, width, height], fill=teal_color)
    
    # Add black right-pointing chevrons on the left side
    chevron_color = (0, 0, 0)  # Black chevrons
    
    # Draw two chevrons pointing right (smaller on top, larger below)
    chevron_sizes = [12, 16]
    chevron_x = 30
    chevron_y_base = height // 2
    
    for i, size in enumerate(chevron_sizes):
        y_offset = i * 8  # Stack them vertically
        y = chevron_y_base - 8 + y_offset
        
        # Draw right-pointing chevron (triangle pointing right)
        points = [
            (chevron_x, y),  # Left point
            (chevron_x + size, y + size // 2),  # Right point
            (chevron_x, y + size)  # Bottom point
        ]
        draw.polygon(points, fill=chevron_color)
    
    # Add "KAMI/WAZA" text on the right side
    try:
        font = ImageFont.truetype("arial.ttf", 16)
    except:
        font = ImageFont.load_default()
    
    # Split text like the logo
    text_top = "KAMI"
    text_bottom = "WAZA"
    
    # Calculate text positions
    bbox_top = draw.textbbox((0, 0), text_top, font=font)
    bbox_bottom = draw.textbbox((0, 0), text_bottom, font=font)
    
    text_width = max(bbox_top[2] - bbox_top[0], bbox_bottom[2] - bbox_bottom[0])
    text_height = (bbox_top[3] - bbox_top[0]) + (bbox_bottom[3] - bbox_bottom[0]) + 2
    
    x = width - text_width - 20
    y = (height - text_height) // 2
    
    # Draw text in white
    draw.text((x, y), text_top, fill=(255, 255, 255), font=font)
    draw.text((x, y + (bbox_top[3] - bbox_top[0]) + 2), text_bottom, fill=(255, 255, 255), font=font)
    
    # Save as BMP
    img.save("banner.bmp", format='BMP')
    print("Created banner.bmp (493x58)")

def create_dialog_bitmap():
    """Create dialog bitmap (493x312 pixels) with Kamiwaza logo design"""
    width, height = 493, 312
    img = Image.new('RGB', (width, height), (255, 255, 255))
    draw = ImageDraw.Draw(img)
    
    # Create teal background
    teal_color = (0, 128, 128)  # Proper teal color
    draw.rectangle([0, 0, width, height], fill=teal_color)
    
    # Add large black right-pointing chevrons in the center
    chevron_color = (0, 0, 0)  # Black chevrons
    
    # Draw two large chevrons pointing right (smaller on top, larger below)
    chevron_sizes = [40, 55]
    chevron_x = width // 2 - 80  # Center the chevrons
    chevron_y_base = height // 2 - 30
    
    for i, size in enumerate(chevron_sizes):
        y_offset = i * 15  # Stack them vertically
        y = chevron_y_base + y_offset
        
        # Draw right-pointing chevron (triangle pointing right)
        points = [
            (chevron_x, y),  # Left point
            (chevron_x + size, y + size // 2),  # Right point
            (chevron_x, y + size)  # Bottom point
        ]
        draw.polygon(points, fill=chevron_color)
    
    # Add "KAMI/WAZA" text below chevrons
    try:
        font = ImageFont.truetype("arial.ttf", 32)
    except:
        font = ImageFont.load_default()
    
    # Split text like the logo
    text_top = "KAMI"
    text_bottom = "WAZA"
    
    # Calculate text positions
    bbox_top = draw.textbbox((0, 0), text_top, font=font)
    bbox_bottom = draw.textbbox((0, 0), text_bottom, font=font)
    
    text_width = max(bbox_top[2] - bbox_top[0], bbox_bottom[2] - bbox_bottom[0])
    text_height = (bbox_top[3] - bbox_top[0]) + (bbox_bottom[3] - bbox_bottom[0]) + 4
    
    x = (width - text_width) // 2
    y = chevron_y_base + 100  # Position below chevrons
    
    # Draw text in white
    draw.text((x, y), text_top, fill=(255, 255, 255), font=font)
    draw.text((x, y + (bbox_top[3] - bbox_top[0]) + 4), text_bottom, fill=(255, 255, 255), font=font)
    
    # Add "Installer" subtitle
    try:
        subtitle_font = ImageFont.truetype("arial.ttf", 14)
    except:
        subtitle_font = ImageFont.load_default()
    
    subtitle = "Installer"
    bbox = draw.textbbox((0, 0), subtitle, font=subtitle_font)
    subtitle_width = bbox[2] - bbox[0]
    subtitle_height = bbox[3] - bbox[1]
    
    subtitle_x = (width - subtitle_width) // 2
    subtitle_y = y + text_height + 8
    
    draw.text((subtitle_x, subtitle_y), subtitle, fill=(255, 255, 255), font=subtitle_font)
    
    # Save as BMP
    img.save("dialog.bmp", format='BMP')
    print("Created dialog.bmp (493x312)")

if __name__ == "__main__":
    create_banner_bitmap()
    create_dialog_bitmap()
    print("Custom UI bitmaps created successfully!") 