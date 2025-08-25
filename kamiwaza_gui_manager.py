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

class KamiwazaGUIManager:
    def __init__(self, root):
        self.root = root
        self.root.title("Kamiwaza GUI Manager")
        self.root.geometry("1000x800")  # Increased window size
        self.root.resizable(True, True)
        
        # Set icon if available
        try:
            icon_path = os.path.join(os.path.dirname(__file__), 'kamiwaza.ico')
            if os.path.exists(icon_path):
                self.root.iconbitmap(icon_path)
        except:
            pass
        
        # Initialize variables
        self.wsl_distribution = "kamiwaza"  # Default WSL distribution
        self.is_running = False
        self.output_text = None
        self.all_buttons = []
        self._busy_count = 0
        
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
        
        # Create the main interface
        self.create_widgets()
        
        # Auto-detect WSL distribution
        self.detect_wsl_distribution()
        
        # Initial status check
        self.check_kamiwaza_status()

    def create_widgets(self):
        """Create the main GUI widgets"""
        # Main frame
        main_frame = ttk.Frame(self.root, padding="10")
        main_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        
        # Configure grid weights
        self.root.columnconfigure(0, weight=1)
        self.root.rowconfigure(0, weight=1)
        main_frame.columnconfigure(1, weight=1)
        main_frame.rowconfigure(6, weight=1)
        
        # Title
        title_label = ttk.Label(main_frame, text="Kamiwaza GUI Manager", 
						   style="Title.TLabel")
        title_label.grid(row=0, column=0, columnspan=2, pady=(0, 12), sticky=tk.W)
        
        # WSL Distribution Selection
        dist_frame = ttk.LabelFrame(main_frame, text="WSL Distribution", padding="10", style="Card.TLabelframe")
        dist_frame.grid(row=1, column=0, columnspan=2, sticky=(tk.W, tk.E), pady=(0, 10))
        
        ttk.Label(dist_frame, text="Distribution:").grid(row=0, column=0, padx=(0, 10))
        self.dist_var = tk.StringVar(value=self.wsl_distribution)
        dist_entry = ttk.Entry(dist_frame, textvariable=self.dist_var, width=24)
        dist_entry.grid(row=0, column=1, padx=(0, 10))
        
        btn_detect = ttk.Button(dist_frame, text="Detect", command=self.detect_wsl_distribution)
        btn_detect.grid(row=0, column=2, padx=(0, 10))
        self.all_buttons.append(btn_detect)
        
        btn_refresh = ttk.Button(dist_frame, text="Refresh", command=self.refresh_all)
        btn_refresh.grid(row=0, column=3, padx=(0, 10))
        self.all_buttons.append(btn_refresh)
        
        btn_test = ttk.Button(dist_frame, text="Test", command=self.test_wsl_distribution)
        btn_test.grid(row=0, column=4)
        self.all_buttons.append(btn_test)
        
        # Distribution validation
        self.dist_var.trace('w', self.validate_distribution)
        
        # Quick Actions
        quick_frame = ttk.LabelFrame(main_frame, text="Quick Actions", padding="10", style="Card.TLabelframe")
        quick_frame.grid(row=2, column=0, columnspan=2, sticky=(tk.W, tk.E), pady=(0, 10))
        
        btn_start = ttk.Button(quick_frame, text="Start Kamiwaza", command=self.start_kamiwaza)
        btn_start.grid(row=0, column=0, padx=6, pady=6, sticky=(tk.W, tk.E))
        self.all_buttons.append(btn_start)
        
        btn_stop = ttk.Button(quick_frame, text="Stop Kamiwaza", command=self.stop_kamiwaza)
        btn_stop.grid(row=0, column=1, padx=6, pady=6, sticky=(tk.W, tk.E))
        self.all_buttons.append(btn_stop)
        
        btn_status = ttk.Button(quick_frame, text="Kamiwaza Status", command=self.check_kamiwaza_status)
        btn_status.grid(row=0, column=2, padx=6, pady=6, sticky=(tk.W, tk.E))
        self.all_buttons.append(btn_status)
        btn_go_ui = ttk.Button(quick_frame, text="Go to UI", command=self.go_to_ui)
        btn_go_ui.grid(row=0, column=4, padx=6, pady=6, sticky=(tk.W, tk.E))
        self.all_buttons.append(btn_go_ui)
        
        btn_go_api = ttk.Button(quick_frame, text="Go to API", command=self.go_to_api)
        btn_go_api.grid(row=0, column=5, padx=6, pady=6, sticky=(tk.W, tk.E))
        self.all_buttons.append(btn_go_api)
        
        btn_logs = ttk.Button(quick_frame, text="View Logs", command=self.view_kamiwaza_logs)
        btn_logs.grid(row=0, column=3, padx=6, pady=6, sticky=(tk.W, tk.E))
        self.all_buttons.append(btn_logs)
        
        
        for i in range(6):
            quick_frame.columnconfigure(i, weight=1)
        
        # GPU & WSL
        gpu_frame = ttk.LabelFrame(main_frame, text="GPU & WSL", padding="10", style="Card.TLabelframe")
        gpu_frame.grid(row=3, column=0, columnspan=2, sticky=(tk.W, tk.E), pady=(0, 10))
        
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
        
        # Advanced
        advanced_frame = ttk.LabelFrame(main_frame, text="Advanced", padding="10", style="Card.TLabelframe")
        advanced_frame.grid(row=4, column=0, columnspan=2, sticky=(tk.W, tk.E), pady=(0, 10))
        
        btn_fix = ttk.Button(advanced_frame, text="Fix WSL Issues", command=self.fix_wsl_issues)
        btn_fix.grid(row=0, column=0, padx=6, pady=6, sticky=(tk.W, tk.E))
        self.all_buttons.append(btn_fix)
        
        btn_open_appdata = ttk.Button(advanced_frame, text="Open AppData", command=self.open_appdata_folder)
        btn_open_appdata.grid(row=0, column=1, padx=6, pady=6, sticky=(tk.W, tk.E))
        self.all_buttons.append(btn_open_appdata)
        
        for i in range(2):
            advanced_frame.columnconfigure(i, weight=1)
        
        # Danger Zone (Destructive)
        danger_frame = ttk.LabelFrame(main_frame, text="Danger Zone (Destructive)", padding="10", style="Card.TLabelframe")
        danger_frame.grid(row=5, column=0, columnspan=2, sticky=(tk.W, tk.E), pady=(0, 10))
        
        btn_reinstall = ttk.Button(danger_frame, text="Reinstall Kamiwaza", command=self.reinstall_kamiwaza)
        btn_reinstall.grid(row=0, column=0, padx=6, pady=6, sticky=(tk.W, tk.E))
        self.all_buttons.append(btn_reinstall)
        
        btn_clean = ttk.Button(danger_frame, text="Clean WSL", command=self.clean_wsl)
        btn_clean.grid(row=0, column=1, padx=6, pady=6, sticky=(tk.W, tk.E))
        self.all_buttons.append(btn_clean)
        
        for i in range(2):
            danger_frame.columnconfigure(i, weight=1)
        
        # Output area
        output_frame = ttk.LabelFrame(main_frame, text="Output & Logs", padding="10", style="Card.TLabelframe")
        output_frame.grid(row=6, column=0, columnspan=2, sticky=(tk.W, tk.E, tk.N, tk.S), pady=(10, 0))
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
        status_bar.grid(row=7, column=0, columnspan=2, sticky=(tk.W, tk.E), pady=(10, 0))
        
        lbl_status = ttk.Label(status_bar, textvariable=self.status_var, relief=tk.SUNKEN, anchor=tk.W)
        lbl_status.pack(side=tk.LEFT, fill=tk.X, expand=True)
        
        self.progress = ttk.Progressbar(status_bar, mode='indeterminate', length=160)
        self.progress.pack(side=tk.RIGHT, padx=(10, 0))
        
        # Configure styles
        self.configure_styles()

    def configure_styles(self):
        """Configure theme and styles for a cleaner, native look"""
        style = ttk.Style()
        try:
            # Prefer native Windows themes when available
            if 'vista' in style.theme_names():
                style.theme_use('vista')
            elif 'xpnative' in style.theme_names():
                style.theme_use('xpnative')
            else:
                style.theme_use('clam')
        except Exception:
            pass
        
        style.configure("Title.TLabel", font=("Segoe UI", 16, "bold"))
        style.configure("Card.TLabelframe", padding=12)
        style.configure("Card.TLabelframe.Label", font=("Segoe UI", 10, "bold"))

    def _enter_busy(self, message):
        self._busy_count += 1
        if self._busy_count == 1:
            self.status_var.set(message)
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
            self.status_var.set("Ready")
            try:
                self.progress.stop()
            except Exception:
                pass
            for b in self.all_buttons:
                try:
                    b.configure(state=tk.NORMAL)
                except Exception:
                    pass

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
            result = subprocess.run(command, capture_output=True, text=True, timeout=timeout, encoding='utf-8', errors='replace')
            
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
            result = subprocess.run(wsl_cmd, capture_output=True, text=True, timeout=timeout, encoding='utf-8', errors='replace')
            return result.returncode == 0
        except Exception:
            return False

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
                
                self.dist_var.set(self.wsl_distribution)
                self.log_output(f"Selected distribution: {self.wsl_distribution}", level="SUCCESS")
                
            else:
                self.log_output("Verbose detection also failed", level="ERROR")
                self.wsl_distribution = 'kamiwaza'  # Default fallback
                self.dist_var.set(self.wsl_distribution)
                
        except Exception as e:
            self.log_output(f"Verbose detection error: {e}", level="ERROR")
            self.wsl_distribution = 'kamiwaza'  # Default fallback
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
            self.run_wsl_command(['kamiwaza', 'start'], "Starting Kamiwaza service")
            #self.check_kamiwaza_status()
        
        threading.Thread(target=start_thread, daemon=True).start()

    def stop_kamiwaza(self):
        """Stop Kamiwaza service"""
        def stop_thread():
            self.run_wsl_command(['kamiwaza', 'stop'], "Stopping Kamiwaza service")
            #self.check_kamiwaza_status()
        
        threading.Thread(target=stop_thread, daemon=True).start()

    def check_kamiwaza_status(self):
        """Check Kamiwaza service status"""
        def status_thread():
            self.run_wsl_command(['kamiwaza', 'status'], "Checking Kamiwaza status")
            
            # Check key Kamiwaza processes with better formatting
            self.check_kamiwaza_processes()
        
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
                self.log_output("✓ Daemon process found", level="SUCCESS")
            else:
                self.log_output("✗ Daemon process not found", level="ERROR")
            
            # Check main Kamiwaza application
            main_result = self.run_wsl_command_silent(['pgrep', '-f', 'main.py'])
            results['main'] = main_result
            if main_result:
                self.log_output("✓ Main application processes found", level="SUCCESS")
            else:
                self.log_output("✗ Main application processes not found", level="ERROR")
            
            # Check frontend processes
            frontend_result = self.run_wsl_command_silent(['pgrep', '-f', 'kamiwaza-frontend'])
            results['frontend'] = frontend_result
            if frontend_result:
                self.log_output("✓ Frontend processes found", level="SUCCESS")
            else:
                self.log_output("✗ Frontend processes not found", level="ERROR")
            
            # Check Ray processes
            ray_result = self.run_wsl_command_silent(['pgrep', '-f', 'ray::'])
            results['ray'] = ray_result
            if ray_result:
                self.log_output("✓ Ray processes found", level="SUCCESS")
            else:
                self.log_output("✗ Ray processes not found", level="ERROR")
            
            # Show a summary of key processes
            self.run_wsl_command(['ps', 'h', '-o', 'pid,ppid,cmd', '-C', 'python'], "Python processes summary")
            
            # Check if specific ports are listening
            https_result = self.run_wsl_command_silent(['netstat', '-tlnp', '2>/dev/null', '|', 'grep', ':443'])
            results['https'] = https_result
            if https_result:
                self.log_output("✓ HTTPS port (443) is listening", level="SUCCESS")
            else:
                self.log_output("✗ HTTPS port (443) not listening", level="ERROR")
            
            api_result = self.run_wsl_command_silent(['netstat', '-tlnp', '2>/dev/null', '|', 'grep', ':7777'])
            results['api'] = api_result
            if api_result:
                self.log_output("✓ API port (7777) is listening", level="SUCCESS")
            else:
                self.log_output("✗ API port (7777) not listening", level="ERROR")
            
            ray_dashboard_result = self.run_wsl_command_silent(['netstat', '-tlnp', '2>/dev/null', '|', 'grep', ':8265'])
            results['ray_dashboard'] = ray_dashboard_result
            if ray_dashboard_result:
                self.log_output("✓ Ray dashboard port (8265) is listening", level="SUCCESS")
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
                'daemon': '✓' if results['daemon'] else '✗',
                'main': '✓' if results['main'] else '✗', 
                'frontend': '✓' if results['frontend'] else '✗',
                'ray': '✓' if results['ray'] else '✗',
                'https': '✓' if results['https'] else '✗',
                'api': '✓' if results['api'] else '✗',
                'ray_dashboard': '✓' if results['ray_dashboard'] else '✗'
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
                self.run_wsl_command(['lspci', '|', 'grep', '-i', 'vga'], "Basic GPU detection")
                
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
            self.run_command(['wsl', '--status'], "WSL status check")
            self.run_command(['wsl', '--list', '--verbose'], "WSL distribution list")
            
            # Check WSL version
            self.run_command(['wsl', '--version'], "WSL version check")
        
        threading.Thread(target=wsl_status_thread, daemon=True).start()

    def fix_wsl_issues(self):
        """Attempt to fix common WSL issues"""
        def fix_thread():
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
        try:
            self.log_output("Opening UI: https://localhost/", level="INFO")
            webbrowser.open('https://localhost/', new=2)
            self.log_output("UI opened in default browser", level="SUCCESS")
        except Exception as e:
            self.log_output(f"Failed to open UI: {e}", level="ERROR")

    def go_to_api(self):
        """Open the Kamiwaza API docs in the default browser"""
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
        dist_name = self.dist_var.get().strip()
        if len(dist_name) < 2:
            self.status_var.set("Invalid distribution name - too short")
        elif '\x00' in dist_name:
            self.status_var.set("Invalid distribution name - contains null characters")
        else:
            self.status_var.set("Ready")
            self.wsl_distribution = dist_name

    def test_wsl_distribution(self):
        """Test if the current WSL distribution is accessible"""
        dist_name = self.dist_var.get().strip()
        if len(dist_name) < 2:
            messagebox.showerror("Invalid Distribution", "Distribution name is too short")
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

def main():
    """Main entry point"""
    root = tk.Tk()
    
    # Set application icon if available
    try:
        icon_path = os.path.join(os.path.dirname(__file__), 'kamiwaza.ico')
        if os.path.exists(icon_path):
            root.iconbitmap(icon_path)
    except:
        pass
    
    app = KamiwazaGUIManager(root)
    
    # Center the window
    root.update_idletasks()
    x = (root.winfo_screenwidth() // 2) - (root.winfo_width() // 2)
    y = (root.winfo_screenheight() // 2) - (root.winfo_height() // 2)
    root.geometry(f"+{x}+{y}")
    
    # Start the GUI
    root.mainloop()

if __name__ == "__main__":
    main() 