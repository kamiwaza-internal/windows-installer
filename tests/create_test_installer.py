#!/usr/bin/env python3
"""
Simple script to create a testable version of the Kamiwaza installer
by replacing the DEB_FILE_URL placeholder with a test URL
"""

import os
import shutil
import importlib.util
import argparse
import time

def create_test_installer():
    """Create a testable version of the installer"""
    
    # Read the config to get the DEB_FILE_URL
    deb_url = None
    try:
        with open('config.yaml', 'r') as f:
            for line in f:
                if line.strip().startswith('deb_file_url:'):
                    deb_url = line.split(':', 1)[1].strip()
                    break
    except FileNotFoundError:
        print("config.yaml not found, using test URL")
        deb_url = "https://example.com/test-package.deb"
    
    if not deb_url:
        print("No DEB_FILE_URL found in config.yaml, using test URL")
        deb_url = "https://example.com/test-package.deb"
    
    print(f"Using DEB URL: {deb_url}")
    
    # Read the template file
    template_file = 'kamiwaza_headless_installer.py'
    output_file = 'kamiwaza_headless_installer_test.py'
    
    try:
        with open(template_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Replace the placeholder
        content = content.replace('{{DEB_FILE_URL}}', deb_url)
        
        # Write the testable version
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(content)
        
        print(f"Created testable installer: {output_file}")
        print(f"DEB_FILE_URL placeholder replaced with: {deb_url}")
        
        return output_file
        
    except FileNotFoundError:
        print(f"Template file not found: {template_file}")
        return None
    except Exception as e:
        print(f"Error creating test installer: {e}")
        return None

# -------------------- Simulation Harness --------------------

def _load_module_from_path(module_path):
    """Dynamically load a module from a file path without executing __main__."""
    spec = importlib.util.spec_from_file_location("kamiwaza_installer_test_mod", module_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Cannot load module from path: {module_path}")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

def _install_with_simulation(mod, memory="8GB", email="test@example.com", license_key=None, usage_reporting="1", mode="lite"):
    """Run the installer with simulated external commands and environment.
    Returns (exit_code, log_summary_dict).
    """
    logs = {"run_command_calls": 0, "streaming_calls": 0}

    # Create installer instance
    installer = mod.HeadlessKamiwazaInstaller(memory=memory, version="test", codename="noble", build="1", arch="amd64",
                                              user_email=email, license_key=license_key, usage_reporting=usage_reporting, install_mode=mode)

    # Monkey-patch methods to avoid real side effects
    def fake_run_command(command, timeout=None):
        logs["run_command_calls"] += 1
        cmd_str = " ".join(command)
        # Simulate a few special cases for better realism
        if command[:2] == ['wsl', '--version']:
            return 0, "WSL version: 2.0.0", ""
        if command[:3] == ['wsl', '--list', '--quiet']:
            return 0, "Ubuntu-24.04\nkamiwaza\n", ""
        if 'which' in command:
            return 0, "/usr/bin/file", ""
        if 'tail' in cmd_str or 'cat' in cmd_str or 'grep' in cmd_str:
            return 0, "", ""
        if 'wsl' in command:
            return 0, "ok", ""
        # General success
        return 0, "ok", ""

    def fake_run_command_with_streaming(command, timeout=None, progress_callback=None):
        logs["streaming_calls"] += 1
        # Emit a few synthetic lines to drive progress
        synthetic = [
            "Preparing to unpack ...",
            "Unpacking kamiwaza (test) ...",
            "Setting up kamiwaza (test) ...",
            "Processing triggers for ...",
            "Install complete"
        ]
        for line in synthetic:
            if progress_callback:
                progress_callback(line)
            # Also mimic installer logging side-effect
            installer.log_output(f"  INSTALL: {line}")
            time.sleep(0.01)
        return 0, "\n".join(synthetic), ""

    def fake_check_wsl_prerequisites():
        return True

    def fake_get_wsl_distribution():
        return ['wsl', '-d', 'kamiwaza']

    def fake_true(*args, **kwargs):
        return True

    def fake_noop(*args, **kwargs):
        return None

    # Apply patches
    installer.run_command = fake_run_command
    installer.run_command_with_streaming = fake_run_command_with_streaming
    installer.check_wsl_prerequisites = fake_check_wsl_prerequisites
    installer.get_wsl_distribution = fake_get_wsl_distribution
    installer.configure_wsl_memory = fake_true
    installer.configure_debconf = fake_noop
    installer.configure_swap_space = fake_noop
    installer.disable_ipv6_wsl = fake_noop
    installer.download_gpu_drivers = fake_noop
    installer.copy_logs_to_windows = fake_noop
    installer.verify_and_show_logs = fake_noop

    # Run install with simulation
    exit_code = installer.install()
    return exit_code, logs

def simulate_msi_prompt(exit_code, accept_reboot=True):
    """Simulate MSI handling of reboot prompt based on installer exit code."""
    if exit_code == 3010:
        print("[MSI] Reboot required (3010). Showing reboot prompt...")
        print(f"[MSI] User {'accepted' if accept_reboot else 'chose later'} reboot.")
    elif exit_code == 0:
        print("[MSI] Installation completed without reboot.")
    else:
        print(f"[MSI] Installation failed with exit code {exit_code}.")

def run_repeatability_simulation(installer_path, repeats=2, accept_reboot=True):
    """Run the simulated installer multiple times to validate repeatability and reboot behavior."""
    mod = _load_module_from_path(installer_path)
    results = []
    for i in range(repeats):
        print(f"\n=== SIMULATION RUN {i+1}/{repeats} ===")
        code, logs = _install_with_simulation(mod)
        print(f"Simulated installer exit code: {code}")
        print(f"Simulated calls: run_command={logs['run_command_calls']}, streaming={logs['streaming_calls']}")
        simulate_msi_prompt(code, accept_reboot=accept_reboot)
        results.append(code)
    # Basic assertion: all runs should be reboot-required (3010) in our current flow
    all_ok = all(c in (0, 3010) for c in results)
    print(f"\nRepeatability check: {'PASSED' if all_ok else 'FAILED'} (codes={results})")
    return all_ok

# -------------------- CLI --------------------

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Create and/or simulate the Kamiwaza test installer')
    parser.add_argument('--simulate', action='store_true', help='Fake run the installer with a simulated environment')
    parser.add_argument('--repeats', type=int, default=2, help='Number of simulation repeats')
    parser.add_argument('--accept-reboot', action='store_true', help='Simulate accepting the MSI reboot prompt')

    args = parser.parse_args()

    test_file = create_test_installer()
    if test_file:
        print(f"\nYou can now test the installer with:")
        print(f"python {test_file} --help")
        print(f"python {test_file} --memory 8GB --email test@example.com") 

    if args.simulate:
        if not test_file or not os.path.exists(test_file):
            # Try to use existing file name if already present
            candidate = 'kamiwaza_headless_installer_test.py'
            if os.path.exists(candidate):
                test_file = candidate
            else:
                print("No test installer available to simulate.")
                raise SystemExit(1)
        print("\nStarting simulated installer runs (no real system changes will be made)...")
        ok = run_repeatability_simulation(test_file, repeats=max(1, args.repeats), accept_reboot=args.accept_reboot)
        raise SystemExit(0 if ok else 2) 