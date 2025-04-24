import os
import sys
import subprocess
import shutil

def check_requirements():
    """Check if all required packages are installed."""
    try:
        subprocess.check_call([sys.executable, "-m", "pip", "install", "-r", "requirements.txt"])
        print("✓ All requirements installed successfully")
    except subprocess.CalledProcessError as e:
        print(f"Error installing requirements: {e}")
        sys.exit(1)

def build_executable():
    """Build the executable using PyInstaller."""
    try:
        # Clean previous builds
        if os.path.exists("build"):
            shutil.rmtree("build")
        if os.path.exists("dist"):
            shutil.rmtree("dist")
        
        print("Building executable...")
        
        # PyInstaller command with all necessary options
        cmd = [
            "pyinstaller",
            "--onefile",                    # Create a single executable
            "--noconsole",                  # Don't show console window
            "--name", "kamiwaza_installer", # Name of the executable
            "--clean",                      # Clean PyInstaller cache
            "--add-data", "kamiwaza-deploy-full.deb;.",  # Include the deb file
            "windows_installer.py"          # Main script
        ]
        
        # Add icon if it exists
        if os.path.exists("kamiwaza.ico"):
            cmd.extend(["--icon", "kamiwaza.ico"])
        
        subprocess.check_call(cmd)
        
        print("✓ Executable built successfully")
        
        # Copy README and other necessary files to dist
        shutil.copy("README.md", "dist/")
        print("✓ Documentation copied to dist folder")
        
        print("\nBuild completed! The executable is in the dist folder.")
        print("You can now distribute kamiwaza_installer.exe")
        
    except subprocess.CalledProcessError as e:
        print(f"Error building executable: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"Unexpected error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    print("Starting build process...")
    check_requirements()
    build_executable() 