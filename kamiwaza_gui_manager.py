#!/usr/bin/env python3
"""
Kamiwaza GUI Manager
A standalone GUI application for managing Kamiwaza WSL instances and GPU acceleration

This application provides easy access to:
- WSL Kamiwaza commands (start/stop/status)
- GPU detection and setup
- PowerShell management scripts
- System information and diagnostics

Separate from the headless installer - designed for ongoing management
"""

import tkinter as tk
from tkinter import ttk, messagebox, scrolledtext
import subprocess
import os
import sys
import threading
import json
import datetime
from pathlib import Path
import webbrowser
import time
import pystray
from PIL import Image, ImageDraw
import psutil
import tempfile
import atexit
import sv_ttk
try:
    import pywinstyles
    PYWINSTYLES_AVAILABLE = True
except ImportError:
    PYWINSTYLES_AVAILABLE = False

class SingleInstance:
    """Ensure only one instance of the application runs - Windows-specific implementation"""
    
    def __init__(self, app_name="KamiwazaManager"):
        self.app_name = app_name
        self.process_names = [
            "KamiwazaGUIManager.exe",  # Compiled EXE name
            "kamiwaza_gui_manager.py", # Script name
            "python.exe",             # Python interpreter (fallback)
            "pythonw.exe"             # Python windowed interpreter
        ]
        # Use a more persistent location for lock file
        self.lock_path = os.path.join(os.environ.get('LOCALAPPDATA', tempfile.gettempdir()), 'Kamiwaza', 'manager.lock')
        
    def is_already_running(self):
        """Check if another instance is already running using file lock method"""
        try:
            # First, try to acquire the lock file
            if os.path.exists(self.lock_path):
                # Check if the PID in the lock file is still running
                try:
                    with open(self.lock_path, 'r') as f:
                        old_pid = int(f.read().strip())
                    
                    # Check if that PID is still running and is our process
                    try:
                        old_process = psutil.Process(old_pid)
                        old_name = old_process.name().lower()
                        
                        # Check if it's actually our process type
                        if ('kamiwazaguimanager.exe' in old_name or 
                            ('python' in old_name and 'kamiwaza_gui_manager.py' in ' '.join(old_process.cmdline()).lower())):
                            return True
                        else:
                            self._cleanup_stale_lock()
                    except psutil.NoSuchProcess:
                        self._cleanup_stale_lock()
                    except Exception:
                        self._cleanup_stale_lock()
                        
                except (ValueError, FileNotFoundError):
                    self._cleanup_stale_lock()
            
            return False
            
        except Exception:
            return False
    
    def _cleanup_stale_lock(self):
        """Clean up stale lock file"""
        try:
            if os.path.exists(self.lock_path):
                os.remove(self.lock_path)
        except Exception:
            pass
    
    def create_lock(self):
        """Create lock file with current PID"""
        try:
            # Ensure directory exists
            lock_dir = os.path.dirname(self.lock_path)
            os.makedirs(lock_dir, exist_ok=True)
            
            with open(self.lock_path, 'w') as f:
                f.write(str(os.getpid()))
            
            # Register cleanup on exit
            atexit.register(self.cleanup)
            return True
        except Exception as e:
            print(f"Failed to create lock file: {e}")
            return False
    
    def cleanup(self):
        """Clean up lock file"""
        try:
            if self.lock_path and os.path.exists(self.lock_path):
                os.remove(self.lock_path)
        except Exception:
            pass

class KamiwazaManager:
    def __init__(self, root, tray_only_mode=False):
        self.root = root
        self.tray_only_mode = tray_only_mode
        
        # Initialize variables first
        self.wsl_distribution = "kamiwaza"  # Default WSL distribution
        self.is_running = False
        self.output_text = None
        self.all_buttons = []
        self._busy_count = 0
        
        # UI variables (may be None in tray-only mode)
        self.dist_var = None
        self.dist_combo = None
        self.notebook = None
        self.status_var = None
        self.progress = None
        self.btn_go_ui = None
        self.btn_go_api = None
        
        # Tray icon variables
        self.tray_icon = None
        self.status_timer = None
        self.is_minimized_to_tray = False
        self.operation_in_progress = False  # Flag to prevent status monitoring override
        
        # Helper function for finding scripts in the correct location
        def find_script(script_name):
            """Find a script in Kamiwaza installation directory or current directory"""
            # Priority 1: Look in Kamiwaza installation directory
            appdata_script = os.path.join(os.environ.get('LOCALAPPDATA', ''), 'Kamiwaza', script_name)
            if os.path.exists(appdata_script):
                return appdata_script
            
            # Priority 2: Look in current script directory (fallback)
            current_script = os.path.join(os.path.dirname(__file__), script_name)
            if os.path.exists(current_script):
                return current_script
            
            return None
        
        self.find_script = find_script
        
        # Only setup full UI if not in tray-only mode
        if not tray_only_mode:
            self.setup_full_ui()
        else:
            self.setup_minimal_ui()
        
        # Setup tray icon (always needed)
        self.setup_tray_icon()
        
        # Override window close behavior
        self.root.protocol("WM_DELETE_WINDOW", self.on_closing)
        
        # Auto-detect WSL distribution
        self.detect_wsl_distribution()
        
        # Initial status check (delayed to ensure GUI is ready)
        self.root.after(500, self.check_kamiwaza_status)
        
        # Set initial web button states (delayed to ensure GUI is ready)
        self.root.after(1000, self.update_web_button_states)
    
    def setup_full_ui(self):
        """Setup the complete GUI interface"""
        self.root.title("Kamiwaza Manager")
        self.root.geometry("1000x800")  # Increased window size
        self.root.resizable(True, True)
        
        # Set icon if available
        try:
            icon_path = os.path.join(os.path.dirname(__file__), 'kamiwaza.ico')
            if os.path.exists(icon_path):
                self.root.iconbitmap(icon_path)
        except:
            pass
        
        # Create the main interface
        self.create_widgets()
    
    def setup_minimal_ui(self):
        """Setup minimal UI for tray-only mode"""
        self.root.title("Kamiwaza Manager")
        # Make window very small and hidden
        self.root.geometry("1x1")
        self.root.resizable(False, False)
        # Immediately withdraw the window
        self.root.withdraw()
        self.is_minimized_to_tray = True
        
        # Set icon if available (for taskbar icon if shown)
        try:
            icon_path = os.path.join(os.path.dirname(__file__), 'kamiwaza.ico')
            if os.path.exists(icon_path):
                self.root.iconbitmap(icon_path)
        except:
            pass

    def create_widgets(self):
        """Create the main GUI widgets"""
        # Main frame
        main_frame = ttk.Frame(self.root, padding="10")
        main_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        
        # Configure grid weights
        self.root.columnconfigure(0, weight=1)
        self.root.rowconfigure(0, weight=1)
        main_frame.columnconfigure(0, weight=1)
        main_frame.rowconfigure(1, weight=1)
        
        # Title
        title_label = ttk.Label(main_frame, text="Kamiwaza Manager", 
						   style="Title.TLabel")
        title_label.grid(row=0, column=0, pady=(0, 12), sticky=tk.W)
        
        # Notebook with tabs
        self.notebook = ttk.Notebook(main_frame)
        self.notebook.grid(row=1, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        
        tab_home = ttk.Frame(self.notebook, padding=10)
        tab_advanced = ttk.Frame(self.notebook, padding=10)
        tab_logs = ttk.Frame(self.notebook, padding=10)
        self.notebook.add(tab_home, text="Home")
        self.notebook.add(tab_advanced, text="Advanced")
        self.notebook.add(tab_logs, text="Logs")
        
        # Home tab layout
        tab_home.columnconfigure(0, weight=1)
        tab_home.rowconfigure(3, weight=1)
        
        # WSL Distribution Selection
        dist_frame = ttk.LabelFrame(tab_home, text="WSL Distribution", padding="10", style="Card.TLabelframe")
        dist_frame.grid(row=0, column=0, sticky=(tk.W, tk.E), pady=(0, 10))
        
        ttk.Label(dist_frame, text="Distribution:").grid(row=0, column=0, padx=(0, 10))
        self.dist_var = tk.StringVar(value=self.wsl_distribution)
        # Modern dropdown (read-only) for distro selection
        self.dist_combo = ttk.Combobox(dist_frame, textvariable=self.dist_var, width=24, state="readonly", values=[])
        self.dist_combo.grid(row=0, column=1, padx=(0, 10))
        
        btn_detect = ttk.Button(dist_frame, text="Detect", command=self.detect_wsl_distribution)
        btn_detect.grid(row=0, column=2, padx=(0, 10))
        self.all_buttons.append(btn_detect)
        
        btn_refresh = ttk.Button(dist_frame, text="Refresh", command=self.refresh_all)
        btn_refresh.grid(row=0, column=3, padx=(0, 10))
        self.all_buttons.append(btn_refresh)
        
        btn_test = ttk.Button(dist_frame, text="Test", command=self.test_wsl_distribution)
        btn_test.grid(row=0, column=4)
        self.all_buttons.append(btn_test)
        
        # Access WSL visible terminal
        btn_access_wsl = ttk.Button(dist_frame, text="Access WSL", command=self.access_wsl_terminal)
        btn_access_wsl.grid(row=0, column=5, padx=(10, 0))
        self.all_buttons.append(btn_access_wsl)
        
        # Distribution validation
        self.dist_var.trace('w', self.validate_distribution)
        
        # Quick Actions
        quick_frame = ttk.LabelFrame(tab_home, text="Quick Actions", padding="10", style="Card.TLabelframe")
        quick_frame.grid(row=1, column=0, sticky=(tk.W, tk.E), pady=(0, 10))
        
        btn_start = ttk.Button(quick_frame, text="Start Kamiwaza", command=self.start_kamiwaza)
        btn_start.grid(row=0, column=0, padx=6, pady=6, sticky=(tk.W, tk.E))
        self.all_buttons.append(btn_start)
        
        btn_stop = ttk.Button(quick_frame, text="Stop Kamiwaza", command=self.stop_kamiwaza)
        btn_stop.grid(row=0, column=1, padx=6, pady=6, sticky=(tk.W, tk.E))
        self.all_buttons.append(btn_stop)
        
        btn_status = ttk.Button(quick_frame, text="Kamiwaza Status", command=self.check_kamiwaza_status)
        btn_status.grid(row=0, column=2, padx=6, pady=6, sticky=(tk.W, tk.E))
        self.all_buttons.append(btn_status)
        
        btn_logs = ttk.Button(quick_frame, text="View Logs", command=self.view_kamiwaza_logs)
        btn_logs.grid(row=0, column=3, padx=6, pady=6, sticky=(tk.W, tk.E))
        self.all_buttons.append(btn_logs)
        
        for i in range(4):
            quick_frame.columnconfigure(i, weight=1)
        
        # Web Navigation row
        web_frame = ttk.LabelFrame(tab_home, text="Web Access", padding="10", style="Card.TLabelframe")
        web_frame.grid(row=2, column=0, sticky=(tk.W, tk.E), pady=(0, 10))
        
        # Green color for buttons
        GREEN_COLOR = "#238636"
        
        self.btn_go_ui = tk.Button(web_frame, text="Go to UI", command=self.go_to_ui,
                                   bg=GREEN_COLOR, fg="white", activebackground="#2a9d42",
                                   activeforeground="white", relief=tk.FLAT, cursor="hand2",
                                   font=("Segoe UI", 10))
        self.btn_go_ui.grid(row=0, column=0, padx=6, pady=6, sticky=(tk.W, tk.E))
        self.all_buttons.append(self.btn_go_ui)
        
        self.btn_go_api = tk.Button(web_frame, text="Go to API", command=self.go_to_api,
                                    bg=GREEN_COLOR, fg="white", activebackground="#2a9d42",
                                    activeforeground="white", relief=tk.FLAT, cursor="hand2",
                                    font=("Segoe UI", 10))
        self.btn_go_api.grid(row=0, column=1, padx=6, pady=6, sticky=(tk.W, tk.E))
        self.all_buttons.append(self.btn_go_api)
        
        for i in range(2):
            web_frame.columnconfigure(i, weight=1)
        
        # Advanced tab
        tab_advanced.columnconfigure(0, weight=1)
        
        advanced_frame = ttk.LabelFrame(tab_advanced, text="Advanced", padding="10", style="Card.TLabelframe")
        advanced_frame.grid(row=0, column=0, sticky=(tk.W, tk.E), pady=(0, 10))
        
        btn_fix = ttk.Button(advanced_frame, text="Fix WSL Issues", command=self.fix_wsl_issues)
        btn_fix.grid(row=0, column=0, padx=6, pady=6, sticky=(tk.W, tk.E))
        self.all_buttons.append(btn_fix)
        
        btn_open_appdata = ttk.Button(advanced_frame, text="Open AppData", command=self.open_appdata_folder)
        btn_open_appdata.grid(row=0, column=1, padx=6, pady=6, sticky=(tk.W, tk.E))
        self.all_buttons.append(btn_open_appdata)
        
        for i in range(2):
            advanced_frame.columnconfigure(i, weight=1)
        
        # GPU & WSL
        gpu_frame = ttk.LabelFrame(tab_advanced, text="GPU & WSL", padding="10", style="Card.TLabelframe")
        gpu_frame.grid(row=1, column=0, sticky=(tk.W, tk.E), pady=(0, 10))
        
        btn_gpu_detect = ttk.Button(gpu_frame, text="GPU Detection & Status", command=self.run_gpu_detection)
        btn_gpu_detect.grid(row=0, column=0, padx=6, pady=6, sticky=(tk.W, tk.E))
        self.all_buttons.append(btn_gpu_detect)
        
        btn_wsl_status = ttk.Button(gpu_frame, text="WSL Status", command=self.check_wsl_status)
        btn_wsl_status.grid(row=0, column=1, padx=6, pady=6, sticky=(tk.W, tk.E))
        self.all_buttons.append(btn_wsl_status)
        
        btn_sys_info = ttk.Button(gpu_frame, text="System Info", command=self.show_system_info)
        btn_sys_info.grid(row=0, column=2, padx=6, pady=6, sticky=(tk.W, tk.E))
        self.all_buttons.append(btn_sys_info)
        
        for i in range(3):
            gpu_frame.columnconfigure(i, weight=1)
        
        danger_frame = ttk.LabelFrame(tab_advanced, text="⚠️ Danger Zone (Destructive)", padding="10", style="Danger.TLabelframe")
        danger_frame.grid(row=2, column=0, sticky=(tk.W, tk.E), pady=(0, 10))
        
        btn_reinstall = ttk.Button(danger_frame, text="Reinstall Kamiwaza", command=self.reinstall_kamiwaza)
        btn_reinstall.grid(row=0, column=0, padx=6, pady=6, sticky=(tk.W, tk.E))
        self.all_buttons.append(btn_reinstall)
        
        btn_clean = ttk.Button(danger_frame, text="Clean WSL", command=self.clean_wsl)
        btn_clean.grid(row=0, column=1, padx=6, pady=6, sticky=(tk.W, tk.E))
        self.all_buttons.append(btn_clean)
        
        for i in range(2):
            danger_frame.columnconfigure(i, weight=1)
        
        # Logs tab
        tab_logs.columnconfigure(0, weight=1)
        tab_logs.rowconfigure(0, weight=1)
        
        output_frame = ttk.LabelFrame(tab_logs, text="Output & Logs", padding="10", style="Card.TLabelframe")
        output_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        output_frame.columnconfigure(0, weight=1)
        output_frame.rowconfigure(0, weight=1)
        
        # Output text area - increased height
        self.output_text = scrolledtext.ScrolledText(output_frame, height=20, width=100, font=("Consolas", 10))
        self.output_text.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        
        # Color tags for log levels
        try:
            self.output_text.tag_config('INFO', foreground='#2563eb')
            self.output_text.tag_config('WARN', foreground='#b45309')
            self.output_text.tag_config('ERROR', foreground='#b91c1c')
            self.output_text.tag_config('SUCCESS', foreground='#107c10')
            self.output_text.tag_config('CMD', foreground='#6b7280')
        except Exception:
            pass
        
        # Output control buttons
        output_buttons_frame = ttk.Frame(output_frame)
        output_buttons_frame.grid(row=1, column=0, sticky=(tk.W, tk.E), pady=(10, 0))
        
        btn_clear = ttk.Button(output_buttons_frame, text="Clear Output", command=self.clear_output)
        btn_clear.pack(side=tk.LEFT, padx=(0, 10))
        self.all_buttons.append(btn_clear)
        
        btn_save = ttk.Button(output_buttons_frame, text="Save Output", command=self.save_output)
        btn_save.pack(side=tk.LEFT, padx=(0, 10))
        self.all_buttons.append(btn_save)
        
        btn_copy = ttk.Button(output_buttons_frame, text="Copy to Clipboard", command=self.copy_to_clipboard)
        btn_copy.pack(side=tk.LEFT)
        self.all_buttons.append(btn_copy)
        
        # Status bar with progress indicator
        self.status_var = tk.StringVar(value="Ready")
        status_bar = ttk.Frame(main_frame)
        status_bar.grid(row=2, column=0, sticky=(tk.W, tk.E), pady=(10, 0))
        
        lbl_status = ttk.Label(status_bar, textvariable=self.status_var, relief=tk.SUNKEN, anchor=tk.W)
        lbl_status.pack(side=tk.LEFT, fill=tk.X, expand=True)
        
        self.progress = ttk.Progressbar(status_bar, mode='indeterminate', length=160)
        self.progress.pack(side=tk.RIGHT, padx=(10, 0))
        
        # Configure styles
        self.configure_styles()

    def configure_styles(self):
        """Configure Sun Valley theme for modern Windows 11 look"""
        try:
            # Apply Sun Valley theme - modern Windows 11 style
            sv_ttk.set_theme("dark")
            print("Applied Sun Valley dark theme")
        except Exception as e:
            print(f"Failed to apply Sun Valley theme: {e}")
            # Fallback to default styling
            style = ttk.Style()
            try:
                if 'vista' in style.theme_names():
                    style.theme_use('vista')
                elif 'xpnative' in style.theme_names():
                    style.theme_use('xpnative')
                else:
                    style.theme_use('clam')
            except Exception:
                pass
        
        # Apply Windows title bar styling for better integration
        self.apply_title_bar_styling()
        
        # Configure additional custom styles that work with Sun Valley
        style = ttk.Style()
        
        # Title styling
        style.configure("Title.TLabel", font=("Segoe UI", 16, "bold"))
        
        # Danger Zone styling - red accent
        try:
            style.configure("Danger.TLabelframe.Label", font=("Segoe UI", 10, "bold"), foreground="#ff4444")
            print("Applied Danger Zone styling")
        except Exception:
            pass
        
        # Enhance scrollbar styling for better theme integration
        self.enhance_scrollbar_styling()

    def apply_title_bar_styling(self):
        """Apply Windows title bar styling for better theme integration"""
        if not PYWINSTYLES_AVAILABLE:
            print("pywinstyles not available - skipping title bar styling")
            return
        
        try:
            import sys
            version = sys.getwindowsversion()
            
            if version.major == 10 and version.build >= 22000:
                # Windows 11 - set title bar color to match dark theme
                pywinstyles.change_header_color(self.root, "#1c1c1c")
                print("Applied Windows 11 title bar styling")
            elif version.major == 10:
                # Windows 10 - apply dark style
                pywinstyles.apply_style(self.root, "dark")
                # Hacky way to update title bar color on Windows 10
                self.root.wm_attributes("-alpha", 0.99)
                self.root.wm_attributes("-alpha", 1)
                print("Applied Windows 10 dark title bar styling")
        except Exception as e:
            print(f"Failed to apply title bar styling: {e}")

    def enhance_scrollbar_styling(self):
        """Enhance scrollbar styling for better theme integration"""
        try:
            style = ttk.Style()
            
            # Configure scrollbar colors to match the dark theme
            style.configure("Vertical.TScrollbar",
                           background="#2d2d2d",
                           troughcolor="#1c1c1c",
                           bordercolor="#2d2d2d",
                           arrowcolor="#ffffff",
                           darkcolor="#2d2d2d",
                           lightcolor="#2d2d2d")
            
            style.map("Vertical.TScrollbar",
                     background=[('active', '#404040'), ('pressed', '#505050')])
            
            # Also configure horizontal scrollbar
            style.configure("Horizontal.TScrollbar",
                           background="#2d2d2d",
                           troughcolor="#1c1c1c", 
                           bordercolor="#2d2d2d",
                           arrowcolor="#ffffff",
                           darkcolor="#2d2d2d",
                           lightcolor="#2d2d2d")
            
            style.map("Horizontal.TScrollbar",
                     background=[('active', '#404040'), ('pressed', '#505050')])
            
            print("Enhanced scrollbar styling")
        except Exception as e:
            print(f"Failed to enhance scrollbar styling: {e}")

    def switch_to_logs_tab(self):
        """Switch to the logs tab to monitor results"""
        if self.notebook:
            try:
                self.notebook.select(2)  # Select the logs tab (index 2)
            except Exception:
                pass

    def _enter_busy(self, message):
        self._busy_count += 1
        if self._busy_count == 1:
            if self.status_var:
                self.status_var.set(message)
            if self.progress:
                self.progress.start(12)
            for b in self.all_buttons:
                try:
                    b.configure(state=tk.DISABLED)
                except Exception:
                    pass

    def _leave_busy(self):
        if self._busy_count > 0:
            self._busy_count -= 1
        if self._busy_count == 0:
            if self.status_var:
                self.status_var.set("Ready")
            if self.progress:
                try:
                    self.progress.stop()
                except Exception:
                    pass
            for b in self.all_buttons:
                try:
                    b.configure(state=tk.NORMAL)
                except Exception:
                    pass
            # Update web navigation button states
            self.update_web_button_states()

    def update_web_button_states(self):
        """Update the state of web navigation buttons based on Kamiwaza running status"""
        if not self.btn_go_ui or not self.btn_go_api:
            return  # Skip if buttons don't exist (tray-only mode)
        
        # Check if Kamiwaza is running (silently)
        is_running = self.run_wsl_command_silent(['kamiwaza', 'status'])
        
        # Green color for buttons
        GREEN_COLOR = "#238636"
        
        try:
            if is_running:
                self.btn_go_ui.configure(state=tk.NORMAL, text="Go to UI", 
                                        bg=GREEN_COLOR, fg="white", 
                                        activebackground="#2a9d42", activeforeground="white")
                self.btn_go_api.configure(state=tk.NORMAL, text="Go to API",
                                         bg=GREEN_COLOR, fg="white",
                                         activebackground="#2a9d42", activeforeground="white")
            else:
                self.btn_go_ui.configure(state=tk.DISABLED, text="Go to UI (Start Kamiwaza first)",
                                        bg="#555555", fg="#999999")
                self.btn_go_api.configure(state=tk.DISABLED, text="Go to API (Start Kamiwaza first)",
                                         bg="#555555", fg="#999999")
        except Exception:
            pass  # Ignore errors if buttons are not available

    def log_output(self, message, level="INFO"):
        """Add message to output area with timestamp and color tags"""
        timestamp = datetime.datetime.now().strftime("%H:%M:%S")
        formatted_message = f"[{timestamp}] [{level}] {message}\n"
        
        if self.output_text:
            try:
                self.output_text.insert(tk.END, formatted_message, (level,))
            except Exception:
                self.output_text.insert(tk.END, formatted_message)
            self.output_text.see(tk.END)
            self.root.update_idletasks()

    def run_command(self, command, description, timeout=60):
        """Run a command and display output"""
        self._enter_busy(f"Running: {description}")
        self.log_output(f"Running: {description}", level="INFO")
        self.log_output(f"Command: {' '.join(command)}", level="CMD")
        
        try:
            # Use utf-8 encoding to avoid Unicode decode errors
            kwargs = self._get_subprocess_kwargs(visible=False)
            result = subprocess.run(command, capture_output=True, text=True, timeout=timeout, encoding='utf-8', errors='replace', **kwargs)
            
            if result.stdout:
                for line in result.stdout.strip().split('\n'):
                    if line.strip():
                        self.log_output(line, level="INFO")
            
            if result.stderr:
                for line in result.stderr.strip().split('\n'):
                    if line.strip():
                        self.log_output(line, level="WARN")
            
            if result.returncode == 0:
                self.log_output(f"{description} completed successfully", level="SUCCESS")
            else:
                self.log_output(f"{description} failed with exit code {result.returncode}", level="ERROR")
            
            return result.returncode == 0
            
        except subprocess.TimeoutExpired:
            self.log_output(f"{description} timed out after {timeout} seconds", level="ERROR")
            return False
        except Exception as e:
            self.log_output(f"{description} failed with error: {e}", level="ERROR")
            return False
        finally:
            self._leave_busy()

    def run_wsl_command(self, command, description, timeout=60):
        """Run a WSL command with proper encoding handling"""
        # Ensure the distribution name is clean
        clean_dist = self.wsl_distribution.strip()
        if not clean_dist or len(clean_dist) < 2:
            self.log_output(f"Invalid WSL distribution name: '{clean_dist}'", level="ERROR")
            return False
        
        wsl_cmd = ['wsl', '-d', clean_dist, '--'] + command
        return self.run_command(wsl_cmd, description, timeout)

    def run_wsl_command_silent(self, command, timeout=30):
        """Run a WSL command silently and return True/False for success/failure"""
        try:
            clean_dist = self.wsl_distribution.strip()
            if not clean_dist or len(clean_dist) < 2:
                return False
            
            wsl_cmd = ['wsl', '-d', clean_dist, '--'] + command
            kwargs = self._get_subprocess_kwargs(visible=False)
            result = subprocess.run(wsl_cmd, capture_output=True, text=True, timeout=timeout, encoding='utf-8', errors='replace', **kwargs)
            return result.returncode == 0
        except Exception:
            return False

    # Helpers for Windows subprocess window behavior and WSL shell pipelines
    def _get_subprocess_kwargs(self, visible=False, new_console=False):
        kwargs = {}
        if os.name == 'nt':
            try:
                startupinfo = subprocess.STARTUPINFO()
                if not visible:
                    # Hide window
                    startupinfo.dwFlags |= getattr(subprocess, 'STARTF_USESHOWWINDOW', 1)
                    startupinfo.wShowWindow = 0  # SW_HIDE
                kwargs['startupinfo'] = startupinfo
                creationflags = 0
                if not visible:
                    creationflags |= getattr(subprocess, 'CREATE_NO_WINDOW', 0x08000000)
                if new_console:
                    creationflags |= getattr(subprocess, 'CREATE_NEW_CONSOLE', 0x00000010)
                if creationflags:
                    kwargs['creationflags'] = creationflags
            except Exception:
                pass
        return kwargs

    def run_wsl_shell_command(self, cmd_str, description, timeout=60):
        """Run a WSL command string through bash -lc so pipes, redirects work"""
        clean_dist = self.wsl_distribution.strip()
        if not clean_dist or len(clean_dist) < 2:
            self.log_output(f"Invalid WSL distribution name: '{clean_dist}'", level="ERROR")
            return False
        wsl_cmd = ['wsl', '-d', clean_dist, '--', 'bash', '-lc', cmd_str]
        return self.run_command(wsl_cmd, description, timeout)

    def run_wsl_shell_command_silent(self, cmd_str, timeout=30):
        """Run a WSL shell command silently and return True/False"""
        try:
            clean_dist = self.wsl_distribution.strip()
            if not clean_dist or len(clean_dist) < 2:
                return False
            wsl_cmd = ['wsl', '-d', clean_dist, '--', 'bash', '-lc', cmd_str]
            kwargs = self._get_subprocess_kwargs(visible=False)
            result = subprocess.run(wsl_cmd, capture_output=True, text=True, timeout=timeout, encoding='utf-8', errors='replace', **kwargs)
            return result.returncode == 0
        except Exception:
            return False

    def access_wsl_terminal(self):
        """Open a visible terminal for the selected WSL distribution"""
        clean_dist = self.wsl_distribution.strip()
        if not clean_dist or len(clean_dist) < 2:
            self.log_output("Invalid WSL distribution name", level="ERROR")
            return
        self._enter_busy("Opening WSL terminal")
        try:
            # Prefer Windows Terminal if available
            try:
                kwargs = self._get_subprocess_kwargs(visible=True, new_console=True)
                subprocess.Popen(['wt.exe', '-w', 0, 'wsl', '-d', clean_dist], **kwargs)
                self.log_output("Opened Windows Terminal for WSL", level="SUCCESS")
            except Exception:
                # Fallback to PowerShell
                kwargs = self._get_subprocess_kwargs(visible=True, new_console=True)
                subprocess.Popen(['powershell.exe', '-NoExit', '-Command', f"wsl -d {clean_dist}"], **kwargs)
                self.log_output("Opened PowerShell for WSL", level="SUCCESS")
        except Exception as e:
            self.log_output(f"Failed to open WSL terminal: {e}", level="ERROR")
        finally:
            self._leave_busy()

    def detect_wsl_distribution(self):
        """Auto-detect available WSL distributions"""
        self.log_output("Detecting available WSL distributions...", level="INFO")
        
        try:
            # Method 1: Try --list --quiet
            result = subprocess.run(['wsl', '--list', '--quiet'], 
                                  capture_output=True, text=True, timeout=30, encoding='utf-8', errors='replace')
            
            if result.returncode == 0:
                # Clean up the output - remove null characters and normalize
                raw_output = result.stdout
                
                # Remove null characters and normalize line endings
                cleaned_output = raw_output.replace('\x00', '').replace('\r\n', '\n').replace('\r', '\n')
                
                # Split into lines and clean each line
                distributions = []
                for line in cleaned_output.strip().split('\n'):
                    clean_line = line.strip()
                    if clean_line and clean_line not in ['', ' ']:
                        distributions.append(clean_line)
                
                self.log_output(f"Found WSL distributions: {distributions}", level="INFO")
                
                # Prefer kamiwaza, then Ubuntu-24.04, then first available
                if 'kamiwaza' in distributions:
                    self.wsl_distribution = 'kamiwaza'
                elif 'Ubuntu-24.04' in distributions:
                    self.wsl_distribution = 'Ubuntu-24.04'
                elif distributions:
                    self.wsl_distribution = distributions[0]
                else:
                    self.log_output("No distributions found with --quiet, trying verbose mode...", level="WARN")
                    # Fallback to verbose mode
                    self.detect_wsl_distribution_verbose()
                    return
                
                # Update dropdown values and selection (only if UI exists)
                if self.dist_combo:
                    try:
                        self.dist_combo['values'] = distributions
                    except Exception:
                        pass
                if self.dist_var:
                    self.dist_var.set(self.wsl_distribution)
                self.log_output(f"Selected distribution: {self.wsl_distribution}", level="SUCCESS")
                
            else:
                self.log_output("Failed to detect WSL distributions with --quiet, trying verbose mode...", level="WARN")
                # Fallback to verbose mode
                self.detect_wsl_distribution_verbose()
                
        except Exception as e:
            self.log_output(f"Error detecting WSL distributions: {e}", level="ERROR")
            # Fallback to verbose mode
            self.detect_wsl_distribution_verbose()

    def detect_wsl_distribution_verbose(self):
        """Fallback WSL detection using verbose mode"""
        try:
            self.log_output("Trying verbose WSL detection...", level="INFO")
            
            # Use verbose mode and parse the output
            result = subprocess.run(['wsl', '--list', '--verbose'], 
                                  capture_output=True, text=True, timeout=30, encoding='utf-8', errors='replace')
            
            if result.returncode == 0:
                raw_output = result.stdout
                
                # Remove null characters and normalize
                cleaned_output = raw_output.replace('\x00', '').replace('\r\n', '\n').replace('\r', '\n')
                
                # Parse verbose output (skip header line)
                distributions = []
                lines = cleaned_output.strip().split('\n')
                
                for line in lines[1:]:  # Skip header
                    parts = line.strip().split()
                    if len(parts) >= 2:
                        # Handle both "* distribution_name" and "distribution_name" formats
                        if parts[0] == '*':
                            dist_name = parts[1]
                        else:
                            dist_name = parts[0]
                        
                        if dist_name and dist_name not in ['', ' ']:
                            distributions.append(dist_name)
                
                self.log_output(f"Verbose detection found: {distributions}", level="INFO")
                
                # Select distribution
                if 'kamiwaza' in distributions:
                    self.wsl_distribution = 'kamiwaza'
                elif 'Ubuntu-24.04' in distributions:
                    self.wsl_distribution = 'Ubuntu-24.04'
                elif distributions:
                    self.wsl_distribution = distributions[0]
                else:
                    self.wsl_distribution = 'kamiwaza'  # Default
                
                # Update dropdown values and selection (only if UI exists)
                if self.dist_combo:
                    try:
                        self.dist_combo['values'] = distributions
                    except Exception:
                        pass
                if self.dist_var:
                    self.dist_var.set(self.wsl_distribution)
                self.log_output(f"Selected distribution: {self.wsl_distribution}", level="SUCCESS")
                
            else:
                self.log_output("Verbose detection also failed", level="ERROR")
                self.wsl_distribution = 'kamiwaza'  # Default fallback
                if self.dist_var:
                    self.dist_var.set(self.wsl_distribution)
                
        except Exception as e:
            self.log_output(f"Verbose detection error: {e}", level="ERROR")
            self.wsl_distribution = 'kamiwaza'  # Default fallback
            if self.dist_var:
                self.dist_var.set(self.wsl_distribution)

    def refresh_all(self):
        """Refresh all status information"""
        self.log_output("Refreshing all status information...", level="INFO")
        self.detect_wsl_distribution()
        self.check_kamiwaza_status()
        self.run_gpu_detection()  # Combined GPU detection and status
        self.log_output("Refresh completed", level="SUCCESS")

    # === KAMIWAZA CONTROL FUNCTIONS ===
    
    def start_kamiwaza(self):
        """Start Kamiwaza service"""
        def start_thread():
            # Set operation in progress flag
            self.operation_in_progress = True
            
            # Update tray icon title
            if self.tray_icon:
                self.tray_icon.title = "Kamiwaza Manager - Starting..."
            
            self.switch_to_logs_tab()
            self.log_output("Starting Kamiwaza platform...", level="INFO")
            success = self.run_wsl_command(['kamiwaza', 'start'], "Starting Kamiwaza service", 3600)
            
            # Update tray icon title based on result
            if self.tray_icon:
                if success:
                    self.tray_icon.title = "Kamiwaza Manager - Running"
                else:
                    self.tray_icon.title = "Kamiwaza Manager - Stopped"
            
            # Clear operation in progress flag
            self.operation_in_progress = False
            # Update web button states after start operation
            self.update_web_button_states()
        
        threading.Thread(target=start_thread, daemon=True).start()

    def stop_kamiwaza(self):
        """Stop Kamiwaza service"""
        def stop_thread():
            # Set operation in progress flag
            self.operation_in_progress = True
            
            # Update tray icon title
            if self.tray_icon:
                self.tray_icon.title = "Kamiwaza Manager - Stopping..."
            
            self.switch_to_logs_tab()
            self.log_output("Stopping Kamiwaza platform...", level="INFO")
            success = self.run_wsl_command(['kamiwaza', 'stop'], "Stopping Kamiwaza service", 3600)
            
            # Update tray icon title based on result
            if self.tray_icon:
                # Always wait a moment for processes to fully stop
                time.sleep(2)
                
                # Check actual status to be sure
                is_running = self.run_wsl_command_silent(['kamiwaza', 'status'])
                if is_running:
                    self.tray_icon.title = "Kamiwaza Manager - Running"
                else:
                    self.tray_icon.title = "Kamiwaza Manager - Stopped"
            
            # Clear operation in progress flag
            self.operation_in_progress = False
            # Update web button states after stop operation
            self.update_web_button_states()
        
        threading.Thread(target=stop_thread, daemon=True).start()

    def check_kamiwaza_status(self):
        """Check Kamiwaza service status"""
        def status_thread():
            # Set operation in progress flag
            self.operation_in_progress = True
            
            # Update tray icon title
            if self.tray_icon:
                self.tray_icon.title = "Kamiwaza Manager - Getting Status..."
            
            self.switch_to_logs_tab()
            self.log_output("Getting status...", level="INFO")
            self.run_wsl_command(['kamiwaza', 'status'], "Checking Kamiwaza status")
            
            # Check key Kamiwaza processes with better formatting
            self.check_kamiwaza_processes()
            
            # Update tray icon title based on actual status
            if self.tray_icon:
                is_running = self.run_wsl_command_silent(['kamiwaza', 'status'])
                if is_running:
                    self.tray_icon.title = "Kamiwaza Manager - Running"
                else:
                    self.tray_icon.title = "Kamiwaza Manager - Stopped"
            
            # Clear operation in progress flag
            self.operation_in_progress = False
            # Update web button states after status check
            self.update_web_button_states()
        
        threading.Thread(target=status_thread, daemon=True).start()

    def check_kamiwaza_processes(self):
        """Check Kamiwaza processes with better formatting"""
        def process_thread():
            self.log_output("=== KAMIWAZA PROCESS STATUS ===", level="INFO")
            
            # Track results for accurate summary
            results = {}
            
            # Check main Kamiwaza daemon
            daemon_result = self.run_wsl_command_silent(['pgrep', '-f', 'kamiwazad.py'])
            results['daemon'] = daemon_result
            if daemon_result:
                self.log_output("[OK] Daemon process found", level="SUCCESS")
            else:
                self.log_output("✗ Daemon process not found", level="ERROR")
            
            # Check main Kamiwaza application
            main_result = self.run_wsl_command_silent(['pgrep', '-f', 'main.py'])
            results['main'] = main_result
            if main_result:
                self.log_output("[OK] Main application processes found", level="SUCCESS")
            else:
                self.log_output("✗ Main application processes not found", level="ERROR")
            
            # Check frontend processes
            frontend_result = self.run_wsl_command_silent(['pgrep', '-f', 'kamiwaza-frontend'])
            results['frontend'] = frontend_result
            if frontend_result:
                self.log_output("[OK] Frontend processes found", level="SUCCESS")
            else:
                self.log_output("✗ Frontend processes not found", level="ERROR")
            
            # Check Ray processes
            ray_result = self.run_wsl_command_silent(['pgrep', '-f', 'ray::'])
            results['ray'] = ray_result
            if ray_result:
                self.log_output("[OK] Ray processes found", level="SUCCESS")
            else:
                self.log_output("✗ Ray processes not found", level="ERROR")
            
            # Show a summary of key processes
            self.run_wsl_command(['ps', 'h', '-o', 'pid,ppid,cmd', '-C', 'python'], "Python processes summary")
            
            # Check if specific ports are listening (via shell so pipes work)
            https_result = self.run_wsl_shell_command_silent('netstat -tlnp 2>/dev/null | grep :443')
            results['https'] = https_result
            if https_result:
                self.log_output("[OK] HTTPS port (443) is listening", level="SUCCESS")
            else:
                self.log_output("✗ HTTPS port (443) not listening", level="ERROR")
            
            api_result = self.run_wsl_shell_command_silent('netstat -tlnp 2>/dev/null | grep :7777')
            results['api'] = api_result
            if api_result:
                self.log_output("[OK] API port (7777) is listening", level="SUCCESS")
            else:
                self.log_output("✗ API port (7777) not listening", level="ERROR")
            
            ray_dashboard_result = self.run_wsl_shell_command_silent('netstat -tlnp 2>/dev/null | grep :8265')
            results['ray_dashboard'] = ray_dashboard_result
            if ray_dashboard_result:
                self.log_output("[OK] Ray dashboard port (8265) is listening", level="SUCCESS")
            else:
                self.log_output("✗ Ray dashboard port (8265) not listening", level="ERROR")
            
            # Generate accurate summary based on actual results
            self.log_output("=== SUMMARY ===", level="INFO")
            
            # Count successes and failures
            total_checks = len(results)
            successful_checks = sum(1 for result in results.values() if result)
            failed_checks = total_checks - successful_checks
            
            # Show individual results
            status_symbols = {
                'daemon': '[OK]' if results['daemon'] else '✗',
                'main': '[OK]' if results['main'] else '✗', 
                'frontend': '[OK]' if results['frontend'] else '✗',
                'ray': '[OK]' if results['ray'] else '✗',
                'https': '[OK]' if results['https'] else '✗',
                'api': '[OK]' if results['api'] else '✗',
                'ray_dashboard': '[OK]' if results['ray_dashboard'] else '✗'
            }
            
            status_levels = {
                'daemon': 'SUCCESS' if results['daemon'] else 'ERROR',
                'main': 'SUCCESS' if results['main'] else 'ERROR',
                'frontend': 'SUCCESS' if results['frontend'] else 'ERROR',
                'ray': 'SUCCESS' if results['ray'] else 'ERROR',
                'https': 'SUCCESS' if results['https'] else 'ERROR',
                'api': 'SUCCESS' if results['api'] else 'ERROR',
                'ray_dashboard': 'SUCCESS' if results['ray_dashboard'] else 'ERROR'
            }
            
            self.log_output(f"{status_symbols['daemon']} Daemon: {'Running' if results['daemon'] else 'Not Running'}", level=status_levels['daemon'])
            self.log_output(f"{status_symbols['main']} Main Application: {'Running' if results['main'] else 'Not Running'}", level=status_levels['main'])
            self.log_output(f"{status_symbols['frontend']} Frontend: {'Running' if results['frontend'] else 'Not Running'}", level=status_levels['frontend'])
            self.log_output(f"{status_symbols['ray']} Ray Processes: {'Running' if results['ray'] else 'Not Running'}", level=status_levels['ray'])
            self.log_output(f"{status_symbols['https']} HTTPS (443): {'Listening' if results['https'] else 'Not Listening'}", level=status_levels['https'])
            self.log_output(f"{status_symbols['api']} API (7777): {'Listening' if results['api'] else 'Not Listening'}", level=status_levels['api'])
            self.log_output(f"{status_symbols['ray_dashboard']} Ray Dashboard (8265): {'Listening' if results['ray_dashboard'] else 'Not Listening'}", level=status_levels['ray_dashboard'])
            
            # Overall status
            if failed_checks == 0:
                self.log_output(f"All systems operational! ({successful_checks}/{total_checks} checks passed)", level="SUCCESS")
            elif successful_checks == 0:
                self.log_output(f"All systems down! ({failed_checks}/{total_checks} checks failed)", level="ERROR")
            else:
                self.log_output(f"System partially operational ({successful_checks}/{total_checks} checks passed, {failed_checks} failed)", level="WARN")
        
        threading.Thread(target=process_thread, daemon=True).start()

    def view_kamiwaza_logs(self):
        """Open Kamiwaza logs folder in AppData"""
        try:
            appdata_logs = os.path.join(os.environ.get('LOCALAPPDATA', ''), 'Kamiwaza', 'logs')
            if os.path.exists(appdata_logs):
                os.startfile(appdata_logs)
                self.log_output(f"Opened logs folder: {appdata_logs}", level="SUCCESS")
            else:
                self.log_output("Kamiwaza logs folder not found", level="WARN")
                self.log_output("Logs may not have been created yet or installation may have failed", level="INFO")
                
                # Try to create the logs directory if it doesn't exist
                try:
                    os.makedirs(appdata_logs, exist_ok=True)
                    self.log_output(f"Created logs directory: {appdata_logs}", level="INFO")
                    os.startfile(appdata_logs)
                    self.log_output("Opened newly created logs folder", level="SUCCESS")
                except Exception as create_err:
                    self.log_output(f"Could not create logs directory: {create_err}", level="ERROR")
        except Exception as e:
            self.log_output(f"Error opening logs folder: {e}", level="ERROR")

    # === GPU MANAGEMENT FUNCTIONS ===
    
    def run_gpu_detection(self):
        """Run GPU detection and show status"""
        def gpu_thread():
            self.switch_to_logs_tab()
            self.log_output("Running GPU detection and status check...", level="INFO")
            
            # Check if PowerShell script exists using helper function
            ps_script = self.find_script('detect_gpu.ps1')
            if ps_script:
                self.log_output(f"Found detect_gpu.ps1 script at: {ps_script}", level="INFO")
                self.log_output(f"Script directory: {os.path.dirname(ps_script)}", level="INFO")
                
                # Run PowerShell script
                ps_cmd = ['powershell.exe', '-ExecutionPolicy', 'Bypass', '-File', ps_script, 
                         '-WSLDistribution', self.wsl_distribution]
                self.run_command(ps_cmd, "GPU detection PowerShell script")
                
                # Check GPU status after detection
                self.check_gpu_status()
            else:
                self.log_output("GPU detection script not found", level="WARN")
                self.log_output("Running basic GPU detection in WSL...", level="INFO")
                self.run_wsl_shell_command('lspci | grep -i vga', "Basic GPU detection")
                
                # Also check GPU status
                self.check_gpu_status()
        
        threading.Thread(target=gpu_thread, daemon=True).start()

    def check_gpu_status(self):
        """Check GPU status and available acceleration"""
        def gpu_status_thread():
            # Check GPU status script if available
            self.run_wsl_command(['/usr/local/bin/kamiwaza_gpu_status.sh'], "GPU status check")
            
            # Check for OpenCL
            self.run_wsl_command(['clinfo', '--list'], "OpenCL platform detection")
            
            # Check for NVIDIA tools
            self.run_wsl_command(['which', 'nvidia-smi'], "NVIDIA driver check")
            
            # Check for Intel tools
            self.run_wsl_command(['which', 'vainfo'], "Intel graphics driver check")
        
        threading.Thread(target=gpu_status_thread, daemon=True).start()

    # === WSL MANAGEMENT FUNCTIONS ===
    
    def check_wsl_status(self):
        """Check WSL status and health"""
        def wsl_status_thread():
            self.switch_to_logs_tab()
            self.run_command(['wsl', '--status'], "WSL status check")
            self.run_command(['wsl', '--list', '--verbose'], "WSL distribution list")
            
            # Check WSL version
            self.run_command(['wsl', '--version'], "WSL version check")
        
        threading.Thread(target=wsl_status_thread, daemon=True).start()

    def fix_wsl_issues(self):
        """Attempt to fix common WSL issues"""
        def fix_thread():
            self.switch_to_logs_tab()
            self.log_output("Attempting to fix WSL issues...", level="INFO")
            
            # Shutdown all WSL instances
            self.run_command(['wsl', '--shutdown'], "Shutting down all WSL instances")
            
            # Wait a moment
            import time
            time.sleep(3)
            
            # Try to start WSL again
            self.run_command(['wsl', '--list'], "Testing WSL functionality")
            
            # Check if our distribution is accessible
            test_cmd = ['wsl', '-d', self.wsl_distribution, '--', 'echo', 'WSL_TEST_SUCCESS']
            self.run_command(test_cmd, "Testing WSL distribution access")
        
        threading.Thread(target=fix_thread, daemon=True).start()

    def clean_wsl(self):
        """Clean WSL environment"""
        if messagebox.askyesno("Confirm Cleanup", 
                              "This will remove the Kamiwaza WSL instance and all data.\n\n"
                              "Are you sure you want to continue?"):
            def clean_thread():
                self.switch_to_logs_tab()
                self.log_output("Cleaning WSL environment...", level="WARN")
                
                # Run cleanup PowerShell script using helper function
                cleanup_script = self.find_script('cleanup_wsl_kamiwaza.ps1')
                if cleanup_script:
                    ps_cmd = ['powershell.exe', '-ExecutionPolicy', 'Bypass', '-File', cleanup_script, '-Force']
                    self.run_command(ps_cmd, "WSL cleanup script")
                else:
                    self.log_output("Cleanup script not found", level="ERROR")
                
                # Refresh status
                self.refresh_all()
            
            threading.Thread(target=clean_thread, daemon=True).start()

    # === SYSTEM MANAGEMENT FUNCTIONS ===
    
    def show_system_info(self):
        """Show system information"""
        def info_thread():
            self.switch_to_logs_tab()
            self.log_output("=== SYSTEM INFORMATION ===", level="INFO")
            
            # Windows system info
            self.run_command(['systeminfo'], "Windows system information")
            
            # WSL info
            self.run_command(['wsl', '--status'], "WSL status")
            
            # GPU info
            try:
                gpu_cmd = ['powershell.exe', '-Command', 
                          'Get-CimInstance Win32_VideoController | Select-Object Name, AdapterCompatibility | ConvertTo-Json']
                result = subprocess.run(gpu_cmd, capture_output=True, text=True, timeout=30, encoding='utf-8', errors='replace')
                if result.returncode == 0 and result.stdout.strip():
                    self.log_output("Windows GPU information:", level="INFO")
                    for line in result.stdout.strip().split('\n'):
                        self.log_output(line, level="INFO")
            except Exception as e:
                self.log_output(f"Could not get GPU info: {e}", level="WARN")
        
        threading.Thread(target=info_thread, daemon=True).start()

    def reinstall_kamiwaza(self):
        """Reinstall Kamiwaza"""
        if messagebox.askyesno("Confirm Reinstallation", 
                              "This will reinstall Kamiwaza completely.\n\n"
                              "All data will be lost and the system will restart.\n\n"
                              "Are you sure you want to continue?"):
            
            def reinstall_thread():
                self.switch_to_logs_tab()
                self.log_output("Starting Kamiwaza reinstallation...", level="WARN")
                
                # Check if headless installer exists
                installer_path = os.path.join(os.path.dirname(__file__), 'kamiwaza_headless_installer.py')
                if os.path.exists(installer_path):
                    self.log_output("Found headless installer", level="INFO")
                    
                    # Run the installer
                    python_cmd = [sys.executable, installer_path]
                    self.run_command(python_cmd, "Kamiwaza reinstallation")
                else:
                    self.log_output("Headless installer not found", level="ERROR")
                    self.log_output("Please run the installer manually", level="INFO")
            
            threading.Thread(target=reinstall_thread, daemon=True).start()

    def open_appdata_folder(self):
        """Open Kamiwaza AppData folder"""
        try:
            appdata_path = os.path.join(os.environ.get('LOCALAPPDATA', ''), 'Kamiwaza')
            if os.path.exists(appdata_path):
                os.startfile(appdata_path)
                self.log_output(f"Opened AppData folder: {appdata_path}", level="SUCCESS")
            else:
                self.log_output("Kamiwaza AppData folder not found", level="WARN")
        except Exception as e:
            self.log_output(f"Error opening AppData folder: {e}", level="ERROR")

    # === WEB NAVIGATION FUNCTIONS ===
    def go_to_ui(self):
        """Open the Kamiwaza UI in the default browser"""
        # Check if Kamiwaza is running first
        if not self.run_wsl_command_silent(['kamiwaza', 'status']):
            self.log_output("Cannot open UI - Kamiwaza is not running. Please start Kamiwaza first.", level="ERROR")
            if not self.tray_only_mode:
                messagebox.showwarning("Kamiwaza Not Running", 
                                     "Kamiwaza is not running. Please start Kamiwaza first before accessing the UI.")
            return
            
        try:
            self.log_output("Opening UI: https://localhost/", level="INFO")
            webbrowser.open('https://localhost/', new=2)
            self.log_output("UI opened in default browser", level="SUCCESS")
        except Exception as e:
            self.log_output(f"Failed to open UI: {e}", level="ERROR")

    def go_to_api(self):
        """Open the Kamiwaza API docs in the default browser"""
        # Check if Kamiwaza is running first
        if not self.run_wsl_command_silent(['kamiwaza', 'status']):
            self.log_output("Cannot open API - Kamiwaza is not running. Please start Kamiwaza first.", level="ERROR")
            if not self.tray_only_mode:
                messagebox.showwarning("Kamiwaza Not Running", 
                                     "Kamiwaza is not running. Please start Kamiwaza first before accessing the API.")
            return
            
        try:
            self.log_output("Opening API docs: http://localhost:7777/api/docs", level="INFO")
            webbrowser.open('http://localhost:7777/api/docs', new=2)
            self.log_output("API docs opened in default browser", level="SUCCESS")
        except Exception as e:
            self.log_output(f"Failed to open API docs: {e}", level="ERROR")

    # === OUTPUT MANAGEMENT FUNCTIONS ===
    
    def clear_output(self):
        """Clear the output text area"""
        if self.output_text:
            self.output_text.delete(1.0, tk.END)
        self.log_output("Output cleared", level="INFO")

    def save_output(self):
        """Save output to file"""
        try:
            from tkinter import filedialog
            filename = filedialog.asksaveasfilename(
                defaultextension=".txt",
                filetypes=[("Text files", "*.txt"), ("All files", "*.*")],
                title="Save Output As"
            )
            
            if filename and self.output_text:
                content = self.output_text.get(1.0, tk.END)
                with open(filename, 'w', encoding='utf-8') as f:
                    f.write(content)
                self.log_output(f"Output saved to: {filename}", level="SUCCESS")
        
        except Exception as e:
            self.log_output(f"Error saving output: {e}", level="ERROR")

    def copy_to_clipboard(self):
        """Copy output to clipboard"""
        try:
            if self.output_text:
                content = self.output_text.get(1.0, tk.END)
                self.root.clipboard_clear()
                self.root.clipboard_append(content)
                self.log_output("Output copied to clipboard", level="SUCCESS")
        except Exception as e:
            self.log_output(f"Error copying to clipboard: {e}", level="ERROR")

    def validate_distribution(self, *args):
        """Validate the WSL distribution name"""
        if not self.dist_var:
            return  # Skip validation in tray-only mode
        dist_name = self.dist_var.get().strip()
        if len(dist_name) < 2:
            if self.status_var:
                self.status_var.set("Invalid distribution name - too short")
        elif '\x00' in dist_name:
            if self.status_var:
                self.status_var.set("Invalid distribution name - contains null characters")
        else:
            if self.status_var:
                self.status_var.set("Ready")
            self.wsl_distribution = dist_name

    def test_wsl_distribution(self):
        """Test if the current WSL distribution is accessible"""
        if not self.dist_var:
            # In tray-only mode, use the current wsl_distribution value
            dist_name = self.wsl_distribution
        else:
            dist_name = self.dist_var.get().strip()
        
        if len(dist_name) < 2:
            if not self.tray_only_mode:
                messagebox.showerror("Invalid Distribution", "Distribution name is too short")
            else:
                self.log_output("Invalid distribution name - too short", level="ERROR")
            return
        
        self.log_output(f"Testing WSL distribution: {dist_name}", level="INFO")
        
        try:
            test_cmd = ['wsl', '-d', dist_name, '--', 'echo', 'WSL_TEST_SUCCESS']
            result = subprocess.run(test_cmd, capture_output=True, text=True, timeout=30, encoding='utf-8', errors='replace')
            
            if result.returncode == 0:
                self.log_output(f"WSL distribution '{dist_name}' is accessible", level="SUCCESS")
                self.wsl_distribution = dist_name
                self.status_var.set(f"WSL distribution '{dist_name}' is working")
            else:
                self.log_output(f"WSL distribution '{dist_name}' is not accessible", level="ERROR")
                if result.stderr:
                    self.log_output(result.stderr.strip(), level="ERROR")
                self.status_var.set(f"WSL distribution '{dist_name}' failed")
                
        except Exception as e:
            self.log_output(f"Error testing WSL distribution: {e}", level="ERROR")
            self.status_var.set("WSL test failed")

    # === TRAY ICON FUNCTIONALITY ===
    
    def setup_tray_icon(self):
        """Setup system tray icon"""
        try:
            # Create icon image
            icon_image = self.create_tray_icon_image()
            
            # Create menu items - make "Show Kamiwaza Manager" the default action (clickable)
            menu = pystray.Menu(
                pystray.MenuItem("Show Kamiwaza Manager", self.show_window, default=True),
                pystray.Menu.SEPARATOR,
                pystray.MenuItem("Kamiwaza Status", self.tray_show_status),
                pystray.Menu.SEPARATOR,
                pystray.MenuItem("Start Kamiwaza", self.tray_start_kamiwaza),
                pystray.MenuItem("Stop Kamiwaza", self.tray_stop_kamiwaza),
                pystray.Menu.SEPARATOR,
                pystray.MenuItem("Open Kamiwaza", self.tray_open_kamiwaza),
                pystray.Menu.SEPARATOR,
                pystray.MenuItem("Exit", self.tray_quit)
            )
            
            # Create tray icon
            self.tray_icon = pystray.Icon(
                "Kamiwaza",
                icon_image,
                "Kamiwaza Manager",
                menu
            )
            
            # Start tray icon in separate thread
            tray_thread = threading.Thread(target=self.tray_icon.run, daemon=True)
            tray_thread.start()
            
            # Start status monitoring
            self.start_status_monitoring()
            
        except Exception as e:
            print(f"Failed to setup tray icon: {e}")
    
    def create_tray_icon_image(self):
        """Create tray icon image"""
        try:
            # Try to load existing icon
            icon_path = os.path.join(os.path.dirname(__file__), 'kamiwaza.ico')
            if os.path.exists(icon_path):
                return Image.open(icon_path)
        except:
            pass
        
        # Create simple fallback icon
        try:
            # Create a 64x64 image
            image = Image.new('RGB', (64, 64), color='white')
            draw = ImageDraw.Draw(image)
            
            # Draw blue circle
            draw.ellipse([8, 8, 56, 56], fill='#2563eb')
            
            # Draw white "K"
            try:
                # Simple text drawing
                draw.text((20, 20), "K", fill='white')
            except:
                pass
            
            return image
        except:
            # Ultimate fallback
            return Image.new('RGB', (64, 64), color='blue')
    
    def start_status_monitoring(self):
        """Start monitoring Kamiwaza status in background"""
        def monitor():
            while True:
                try:
                    # Check status every 10 seconds
                    threading.Event().wait(10)
                    
                    # Only update tray icon if no operation is in progress
                    if self.tray_icon and not self.operation_in_progress:
                        is_running = self.run_wsl_command_silent(['kamiwaza', 'status'])
                        if is_running:
                            self.tray_icon.title = "Kamiwaza Manager - Running"
                        else:
                            self.tray_icon.title = "Kamiwaza Manager - Stopped"
                            
                except Exception:
                    pass
        
        monitor_thread = threading.Thread(target=monitor, daemon=True)
        monitor_thread.start()
    
    def on_closing(self):
        """Handle window close - minimize to tray instead of closing"""
        self.minimize_to_tray()
    
    def minimize_to_tray(self):
        """Minimize window to tray"""
        self.root.withdraw()  # Hide window
        self.is_minimized_to_tray = True
        
        # Show notification
        if self.tray_icon:
            self.tray_icon.notify("Kamiwaza Manager minimized to tray", "Click the tray icon to restore")
    
    def show_window(self, icon=None, item=None):
        """Show or toggle the main window (clickable tray icon action)"""
        # If in tray-only mode, we need to create the full UI first
        if self.tray_only_mode:
            self.tray_only_mode = False
            self.setup_full_ui()
            # Center the window
            self.root.update_idletasks()
            x = (self.root.winfo_screenwidth() // 2) - (self.root.winfo_width() // 2)
            y = (self.root.winfo_screenheight() // 2) - (self.root.winfo_height() // 2)
            self.root.geometry(f"+{x}+{y}")
        
        # Toggle window visibility - if visible, hide it; if hidden, show it
        try:
            if self.root.winfo_viewable():
                # Window is visible, hide it
                self.minimize_to_tray()
            else:
                # Window is hidden, show it
                self.root.deiconify()  # Show window
                self.root.lift()  # Bring to front
                self.root.focus_force()  # Focus
                self.is_minimized_to_tray = False
        except tk.TclError:
            # Window might not exist yet, just show it
            self.root.deiconify()
            self.root.lift()
            self.root.focus_force()
            self.is_minimized_to_tray = False
    
    def tray_show_status(self, icon=None, item=None):
        """Show status from tray"""
        self.show_window()
        self.check_kamiwaza_status()
    
    def tray_start_kamiwaza(self, icon=None, item=None):
        """Start Kamiwaza from tray"""
        self.start_kamiwaza()
        if self.tray_icon:
            self.tray_icon.notify("Starting Kamiwaza...", "Kamiwaza is starting up")
    
    def tray_stop_kamiwaza(self, icon=None, item=None):
        """Stop Kamiwaza from tray"""
        self.stop_kamiwaza()
        if self.tray_icon:
            self.tray_icon.notify("Stopping Kamiwaza...", "Kamiwaza is shutting down")
    
    def tray_open_kamiwaza(self, icon=None, item=None):
        """Open Kamiwaza in browser from tray"""
        self.go_to_ui()
    
    def tray_quit(self, icon=None, item=None):
        """Quit application from tray"""
        self.quit_application()
    
    def quit_application(self):
        """Quit the application completely"""
        try:
            if self.tray_icon:
                self.tray_icon.stop()
        except:
            pass
        
        try:
            self.root.quit()
            self.root.destroy()
        except:
            pass
        
        # Clean up single instance lock (atexit should handle this, but be explicit)
        try:
            if hasattr(self, 'single_instance'):
                self.single_instance.cleanup()
        except:
            pass
        
        # Force exit
        os._exit(0)

def main():
    """Main entry point"""
    import argparse
    
    # Parse command line arguments
    parser = argparse.ArgumentParser(description='Kamiwaza Manager')
    parser.add_argument('--show', action='store_true', 
                       help='Start with window visible (default is tray only)')
    args = parser.parse_args()
    
    # Check for single instance
    single_instance = SingleInstance("KamiwazaManager")
    if single_instance.is_already_running():
        print("Kamiwaza Manager is already running in the system tray.")
        print("Check your system tray for the Kamiwaza icon.")
        # Show a message box if we're not in a console environment
        try:
            if hasattr(sys, 'ps1') or not hasattr(sys.stderr, 'isatty') or not sys.stderr.isatty():
                # We're in an interactive environment or GUI, show message box
                root = tk.Tk()
                root.withdraw()  # Hide the main window
                root.destroy()
        except Exception:
            pass
        return
    
    # Create lock file
    if not single_instance.create_lock():
        print("Failed to create lock file. Another instance may be starting.")
        return
    
    root = tk.Tk()
    
    # Set application icon if available
    try:
        icon_path = os.path.join(os.path.dirname(__file__), 'kamiwaza.ico')
        if os.path.exists(icon_path):
            root.iconbitmap(icon_path)
    except:
        pass
    
    # Use tray-only mode unless --show is specified
    tray_only_mode = not args.show
    app = KamiwazaManager(root, tray_only_mode=tray_only_mode)
    # Store single instance reference for cleanup
    app.single_instance = single_instance
    
    # If showing the window, center it
    if args.show:
        # Center the window
        root.update_idletasks()
        x = (root.winfo_screenwidth() // 2) - (root.winfo_width() // 2)
        y = (root.winfo_screenheight() // 2) - (root.winfo_height() // 2)
        root.geometry(f"+{x}+{y}")
    else:
        # Show notification that it's running in tray (tray-only mode)
        # Wait a moment for tray icon to be ready
        root.after(1000, lambda: app.tray_icon.notify("Kamiwaza Manager started", "Running in system tray. Click 'Show Kamiwaza Manager' to open.") if app.tray_icon else None)
    
    # Start the GUI
    root.mainloop()

if __name__ == "__main__":
    main() 