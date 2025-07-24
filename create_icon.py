#!/usr/bin/env python3
"""
Create a simple ICO file for Kamiwaza application
"""

from PIL import Image, ImageDraw, ImageFont
import os

def create_kamiwaza_icon():
    """Create a simple icon for Kamiwaza application"""
    
    # Create a 256x256 image (standard size for Windows icons)
    size = 256
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Create a modern gradient background
    for y in range(size):
        # Create a blue to green gradient
        r = int(30 + (y / size) * 40)  # Blue component
        g = int(100 + (y / size) * 100)  # Green component  
        b = int(200 + (y / size) * 55)  # Blue component
        color = (r, g, b, 255)
        draw.line([(0, y), (size, y)], fill=color)
    
    # Add a stylized "K" letter in white
    try:
        # Try to use a system font, fallback to default if not available
        font_size = size // 3
        try:
            font = ImageFont.truetype("arial.ttf", font_size)
        except:
            font = ImageFont.load_default()
    except:
        font = ImageFont.load_default()
    
    # Draw a stylized "K" 
    text = "K"
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    
    x = (size - text_width) // 2
    y = (size - text_height) // 2
    
    # Draw text with white color and slight shadow
    draw.text((x+2, y+2), text, fill=(255, 255, 255, 180), font=font)  # Shadow
    draw.text((x, y), text, fill=(255, 255, 255, 255), font=font)  # Main text
    
    # Add a subtle border
    border_width = 4
    for i in range(border_width):
        draw.rectangle([i, i, size-i-1, size-i-1], outline=(255, 255, 255, 100))
    
    # Save as ICO with multiple sizes
    icon_sizes = [16, 32, 48, 64, 128, 256]
    images = []
    
    for icon_size in icon_sizes:
        resized_img = img.resize((icon_size, icon_size), Image.Resampling.LANCZOS)
        images.append(resized_img)
    
    # Save as ICO file
    img.save("kamiwaza.ico", format='ICO', sizes=[(size, size) for size in icon_sizes])
    print(f"Created kamiwaza.ico with sizes: {icon_sizes}")

if __name__ == "__main__":
    create_kamiwaza_icon() 