#!/usr/bin/env python3
"""
Kamiwaza Installer Validation Test Suite
Validates the entire installer configuration without actually running anything.
This provides a repeatable way to test installer logic and verify all components.
"""

import os
import sys
import xml.etree.ElementTree as ET
import re
from pathlib import Path
from typing import Dict, List, Set, Tuple, Optional
import json
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class InstallerValidator:
    """Validates the entire Kamiwaza installer configuration."""
    
    def __init__(self, wxs_file_path: str = "installer.wxs"):
        self.wxs_file_path = wxs_file_path
        self.tree = None
        self.root = None
        self.validation_results = {
            'passed': [],
            'warnings': [],
            'errors': [],
            'info': []
        }
        
    def load_wxs_file(self) -> bool:
        """Load and parse the WiX file."""
        try:
            if not os.path.exists(self.wxs_file_path):
                self.validation_results['errors'].append(f"WiX file not found: {self.wxs_file_path}")
                return False
                
            self.tree = ET.parse(self.wxs_file_path)
            self.root = self.tree.getroot()
            self.validation_results['info'].append(f"Successfully loaded WiX file: {self.wxs_file_path}")
            return True
        except Exception as e:
            self.validation_results['errors'].append(f"Failed to parse WiX file: {e}")
            return False
    
    def validate_product_properties(self) -> None:
        """Validate product properties and versioning."""
        logger.info("Validating product properties...")
        
        product = self.root.find('.//Product')
        if product is None:
            self.validation_results['errors'].append("Product element not found")
            return
            
        # Check required attributes
        required_attrs = ['Id', 'Name', 'Language', 'Version', 'Manufacturer', 'UpgradeCode']
        for attr in required_attrs:
            if product.get(attr) is None:
                self.validation_results['errors'].append(f"Product missing required attribute: {attr}")
            else:
                self.validation_results['passed'].append(f"Product attribute validated: {attr}")
        
        # Check version format
        version = product.get('Version')
        if version and re.match(r'\$\(var\.KAMIWAZA_VERSION_MAJOR\)\.\$\(var\.KAMIWAZA_VERSION_MINOR\)\.\$\(var\.KAMIWAZA_VERSION_PATCH\)\.0', version):
            self.validation_results['passed'].append("Product version format validated")
        else:
            self.validation_results['warnings'].append(f"Product version format may be incorrect: {version}")
    
    def validate_package_configuration(self) -> None:
        """Validate package configuration."""
        logger.info("Validating package configuration...")
        
        package = self.root.find('.//Package')
        if package is None:
            self.validation_results['errors'].append("Package element not found")
            return
            
        # Check package attributes
        installer_version = package.get('InstallerVersion')
        if installer_version == '200':
            self.validation_results['passed'].append("Package installer version validated (200)")
        else:
            self.validation_results['warnings'].append(f"Unexpected installer version: {installer_version}")
            
        compressed = package.get('Compressed')
        if compressed == 'yes':
            self.validation_results['passed'].append("Package compression enabled")
        else:
            self.validation_results['warnings'].append("Package compression not enabled")
            
        install_scope = package.get('InstallScope')
        if install_scope == 'perUser':
            self.validation_results['passed'].append("Package install scope set to perUser")
        else:
            self.validation_results['warnings'].append(f"Unexpected install scope: {install_scope}")
    
    def validate_directory_structure(self) -> None:
        """Validate the directory structure and file placements."""
        logger.info("Validating directory structure...")
        
        # Check main installation directory
        install_folder = self.root.find('.//Directory[@Id="INSTALLFOLDER"]')
        if install_folder is None:
            self.validation_results['errors'].append("INSTALLFOLDER directory not found")
            return
            
        # Check Python folder
        python_folder = install_folder.find('.//Directory[@Id="PYTHONFOLDER"]')
        if python_folder is None:
            self.validation_results['warnings'].append("PYTHONFOLDER directory not found")
        else:
            self.validation_results['passed'].append("Python runtime directory configured")
        
        # Validate all files in the main component
        main_component = self.root.find('.//Component[@Id="KamiwazaInstallerFiles"]')
        if main_component is None:
            self.validation_results['errors'].append("Main component not found")
            return
            
        expected_files = [
            'download_exe.ps1',
            'kamiwaza_headless_installer.py',
            'run_kamiwaza.bat',
            'configure_wsl_memory.ps1',
            'setup_debconf.sh',
            'setup_passwordless_sudo.sh',
            'config.yaml',
            'cleanup_wsl_kamiwaza.ps1',
            'cleanup_installs.bat',
            'detect_gpu.ps1',
            'detect_gpu_cmd.bat',
            'setup_nvidia_gpu.sh',
            'setup_intel_arc_gpu.sh',
            'start_platform.bat',
            'kamiwaza_start.bat',
            'kamiwaza_stop.bat',
            'kamiwaza_autostart.bat',
            'create_runonce.bat',
            'create_autostart_registry.ps1',
            'KamiwazaGUIManager.exe',
            'install_gui_manager.ps1'
        ]
        
        for expected_file in expected_files:
            file_element = main_component.find(f'.//File[@Name="{expected_file}"]')
            if file_element is None:
                self.validation_results['errors'].append(f"Required file not found: {expected_file}")
            else:
                source = file_element.get('Source')
                if source and os.path.exists(source):
                    self.validation_results['passed'].append(f"File validated: {expected_file} -> {source}")
                else:
                    self.validation_results['warnings'].append(f"File source not found: {expected_file} -> {source}")
    
    def validate_start_menu_shortcuts(self) -> None:
        """Validate Start Menu shortcuts configuration."""
        logger.info("Validating Start Menu shortcuts...")
        
        shortcuts_component = self.root.find('.//Component[@Id="ApplicationShortcut"]')
        if shortcuts_component is None:
            self.validation_results['errors'].append("Start Menu shortcuts component not found")
            return
            
        expected_shortcuts = [
            'InstallKamiwazaShortcut',
            'StartPlatformShortcut',
            'KamiwazaStartShortcut',
            'KamiwazaStopShortcut',
            'CleanupWSLShortcut',
            'CleanupWSLBatchShortcut',
            'SetupAutostartShortcut',
            'KamiwazaMonitorShortcut'
        ]
        
        for shortcut_id in expected_shortcuts:
            shortcut = shortcuts_component.find(f'.//Shortcut[@Id="{shortcut_id}"]')
            if shortcut is None:
                self.validation_results['errors'].append(f"Start Menu shortcut not found: {shortcut_id}")
            else:
                name = shortcut.get('Name')
                target = shortcut.get('Target')
                if name and target:
                    self.validation_results['passed'].append(f"Shortcut validated: {shortcut_id} -> {name}")
                else:
                    self.validation_results['warnings'].append(f"Shortcut missing attributes: {shortcut_id}")
    
    def validate_custom_actions(self) -> None:
        """Validate custom actions and execution sequence."""
        logger.info("Validating custom actions...")
        
        # Check all custom actions exist
        expected_actions = [
            'CheckRemotePC',
            'DetectGPUCmd',
            'DetectGPU',
            'RunKamiwazaInstaller',
            'ReservePorts',
            'ComprehensiveCleanup',
            'ReleasePorts',
            'SetupAutostartRegistry',
            'InstallGUIManager',
            'LaunchDiagnosticGUI',
            'SetRunOnceEntry'
        ]
        
        for action_id in expected_actions:
            action = self.root.find(f'.//CustomAction[@Id="{action_id}"]')
            if action is None:
                self.validation_results['errors'].append(f"Custom action not found: {action_id}")
            else:
                exe_command = action.get('ExeCommand')
                if exe_command:
                    self.validation_results['passed'].append(f"Custom action validated: {action_id}")
                else:
                    self.validation_results['warnings'].append(f"Custom action missing ExeCommand: {action_id}")
        
        # Validate execution sequence
        install_sequence = self.root.find('.//InstallExecuteSequence')
        if install_sequence is None:
            self.validation_results['errors'].append("InstallExecuteSequence not found")
            return
            
        # Check that all custom actions are in the sequence
        sequence_actions = install_sequence.findall('.//Custom')
        sequence_action_ids = [action.get('Action') for action in sequence_actions]
        
        for action_id in expected_actions:
            if action_id in sequence_action_ids:
                self.validation_results['passed'].append(f"Custom action in execution sequence: {action_id}")
            else:
                self.validation_results['warnings'].append(f"Custom action not in execution sequence: {action_id}")
    
    def validate_ui_dialogs(self) -> None:
        """Validate custom UI dialogs."""
        logger.info("Validating UI dialogs...")
        
        ui = self.root.find('.//UI')
        if ui is None:
            self.validation_results['warnings'].append("Custom UI section not found")
            return
            
        expected_dialogs = [
            'KamiwazaConfigDlg',
            'KamiwazaRebootDlg',
            'KamiwazaExitDlg'
        ]
        
        for dialog_id in expected_dialogs:
            dialog = ui.find(f'.//Dialog[@Id="{dialog_id}"]')
            if dialog is None:
                self.validation_results['warnings'].append(f"Custom dialog not found: {dialog_id}")
            else:
                self.validation_results['passed'].append(f"Custom dialog validated: {dialog_id}")
    
    def validate_properties(self) -> None:
        """Validate installer properties."""
        logger.info("Validating installer properties...")
        
        # Check WSL memory configuration
        wsl_memory_prop = self.root.find('.//Property[@Id="WSLMEMORY"]')
        if wsl_memory_prop is not None:
            default_value = wsl_memory_prop.get('Value')
            if default_value == '14GB':
                self.validation_results['passed'].append("WSL memory default value validated: 14GB")
            else:
                self.validation_results['warnings'].append(f"Unexpected WSL memory default: {default_value}")
        else:
            self.validation_results['warnings'].append("WSLMEMORY property not found")
        
        # Check other important properties
        important_props = [
            'KAMIWAZA_VERSION',
            'CODENAME',
            'BUILD_NUMBER',
            'ARCH',
            'USER_EMAIL',
            'LICENSE_KEY',
            'USAGE_REPORTING',
            'INSTALL_MODE',
            'LAUNCH_GUI'
        ]
        
        for prop_id in important_props:
            prop = self.root.find(f'.//Property[@Id="{prop_id}"]')
            if prop is not None:
                self.validation_results['passed'].append(f"Property validated: {prop_id}")
            else:
                self.validation_results['warnings'].append(f"Property not found: {prop_id}")
    
    def validate_file_sources(self) -> None:
        """Validate that all referenced source files actually exist."""
        logger.info("Validating file sources...")
        
        all_files = self.root.findall('.//File')
        missing_sources = []
        
        for file_elem in all_files:
            source = file_elem.get('Source')
            if source and not os.path.exists(source):
                missing_sources.append(f"{file_elem.get('Name')} -> {source}")
        
        if missing_sources:
            for missing in missing_sources:
                self.validation_results['errors'].append(f"Source file not found: {missing}")
        else:
            self.validation_results['passed'].append("All source files found")
    
    def validate_registry_entries(self) -> None:
        """Validate registry entries configuration."""
        logger.info("Validating registry entries...")
        
        # Check main registry value
        main_registry = self.root.find('.//RegistryValue[@Name="installed"]')
        if main_registry is not None:
            self.validation_results['passed'].append("Main registry entry validated")
        else:
            self.validation_results['warnings'].append("Main registry entry not found")
        
        # Check registry cleanup
        registry_cleanup = self.root.find('.//RegistryKey[@ForceDeleteOnUninstall="yes"]')
        if registry_cleanup is not None:
            self.validation_results['passed'].append("Registry cleanup on uninstall configured")
        else:
            self.validation_results['warnings'].append("Registry cleanup on uninstall not configured")
    
    def validate_cleanup_actions(self) -> None:
        """Validate cleanup and uninstall actions."""
        logger.info("Validating cleanup actions...")
        
        # Check file removal actions
        remove_actions = self.root.findall('.//RemoveFile')
        if remove_actions:
            self.validation_results['passed'].append(f"File cleanup actions configured: {len(remove_actions)} actions")
        else:
            self.validation_results['warnings'].append("No file cleanup actions configured")
        
        # Check folder removal
        remove_folder = self.root.find('.//RemoveFolder')
        if remove_folder is not None:
            self.validation_results['passed'].append("Folder cleanup on uninstall configured")
        else:
            self.validation_results['warnings'].append("Folder cleanup on uninstall not configured")
    
    def validate_wsl_integration(self) -> None:
        """Validate WSL-specific integration features."""
        logger.info("Validating WSL integration...")
        
        # Check WSL memory configuration script
        wsl_memory_script = self.root.find('.//File[@Name="configure_wsl_memory.ps1"]')
        if wsl_memory_script is not None:
            self.validation_results['passed'].append("WSL memory configuration script included")
        else:
            self.validation_results['warnings'].append("WSL memory configuration script not found")
        
        # Check GPU detection scripts
        gpu_scripts = ['detect_gpu.ps1', 'detect_gpu_cmd.bat']
        for script in gpu_scripts:
            gpu_script_elem = self.root.find(f'.//File[@Name="{script}"]')
            if gpu_script_elem is not None:
                self.validation_results['passed'].append(f"GPU detection script included: {script}")
            else:
                self.validation_results['warnings'].append(f"GPU detection script not found: {script}")
        
        # Check GPU setup scripts
        gpu_setup_scripts = ['setup_nvidia_gpu.sh', 'setup_intel_arc_gpu.sh']
        for script in gpu_setup_scripts:
            setup_script_elem = self.root.find(f'.//File[@Name="{script}"]')
            if setup_script_elem is not None:
                self.validation_results['passed'].append(f"GPU setup script included: {script}")
            else:
                self.validation_results['warnings'].append(f"GPU setup script not found: {script}")
    
    def validate_gui_components(self) -> None:
        """Validate GUI-related components."""
        logger.info("Validating GUI components...")
        
        # Check GUI manager executable
        gui_exe = self.root.find('.//File[@Name="KamiwazaGUIManager.exe"]')
        if gui_exe is not None:
            self.validation_results['passed'].append("GUI Manager executable included")
        else:
            self.validation_results['warnings'].append("GUI Manager executable not found")
        
        # Check GUI installation script
        gui_install_script = self.root.find('.//File[@Name="install_gui_manager.ps1"]')
        if gui_install_script is not None:
            self.validation_results['passed'].append("GUI installation script included")
        else:
            self.validation_results['warnings'].append("GUI installation script not found")
        
        # Check GUI launch custom action
        gui_launch_action = self.root.find('.//CustomAction[@Id="LaunchDiagnosticGUI"]')
        if gui_launch_action is not None:
            self.validation_results['passed'].append("GUI launch custom action configured")
        else:
            self.validation_results['warnings'].append("GUI launch custom action not configured")
    
    def run_comprehensive_validation(self) -> Dict:
        """Run all validation checks and return results."""
        logger.info("Starting comprehensive installer validation...")
        
        if not self.load_wxs_file():
            return self.validation_results
        
        # Run all validation checks
        validation_methods = [
            self.validate_product_properties,
            self.validate_package_configuration,
            self.validate_directory_structure,
            self.validate_start_menu_shortcuts,
            self.validate_custom_actions,
            self.validate_ui_dialogs,
            self.validate_properties,
            self.validate_file_sources,
            self.validate_registry_entries,
            self.validate_cleanup_actions,
            self.validate_wsl_integration,
            self.validate_gui_components
        ]
        
        for method in validation_methods:
            try:
                method()
            except Exception as e:
                self.validation_results['errors'].append(f"Validation method {method.__name__} failed: {e}")
        
        # Generate summary
        total_checks = len(self.validation_results['passed']) + len(self.validation_results['warnings']) + len(self.validation_results['errors'])
        self.validation_results['summary'] = {
            'total_checks': total_checks,
            'passed': len(self.validation_results['passed']),
            'warnings': len(self.validation_results['warnings']),
            'errors': len(self.validation_results['errors']),
            'success_rate': (len(self.validation_results['passed']) / total_checks * 100) if total_checks > 0 else 0
        }
        
        logger.info("Comprehensive validation completed")
        return self.validation_results
    
    def print_results(self) -> None:
        """Print validation results in a formatted way."""
        results = self.validation_results
        
        print("\n" + "="*80)
        print("KAMIWAZA INSTALLER VALIDATION RESULTS")
        print("="*80)
        
        if results['summary']:
            summary = results['summary']
            print(f"\nSUMMARY:")
            print(f"  Total Checks: {summary['total_checks']}")
            print(f"  Passed: {summary['passed']}")
            print(f"  Warnings: {summary['warnings']}")
            print(f"  Errors: {summary['errors']}")
            print(f"  Success Rate: {summary['success_rate']:.1f}%")
        
        if results['errors']:
            print(f"\n[FAIL] ERRORS ({len(results['errors'])}):")
            for error in results['errors']:
                print(f"  • {error}")
        
        if results['warnings']:
            print(f"\n[WARN] WARNINGS ({len(results['warnings'])}):")
            for warning in results['warnings']:
                print(f"  • {warning}")
        
        if results['passed']:
            print(f"\n[OK] PASSED ({len(results['passed'])}):")
            for passed in results['passed'][:10]:  # Show first 10
                print(f"  • {passed}")
            if len(results['passed']) > 10:
                print(f"  ... and {len(results['passed']) - 10} more")
        
        if results['info']:
            print(f"\n[INFO] INFO ({len(results['info'])}):")
            for info in results['info']:
                print(f"  • {info}")
        
        print("\n" + "="*80)
        
        # Overall status
        if results['errors']:
            print("[FAIL] VALIDATION FAILED - Critical issues found")
        elif results['warnings']:
            print("[WARN] VALIDATION PASSED WITH WARNINGS")
        else:
            print("[OK] VALIDATION PASSED - All checks successful")
        
        print("="*80 + "\n")
    
    def export_results(self, output_file: str = "installer_validation_results.json") -> None:
        """Export validation results to JSON file."""
        try:
            with open(output_file, 'w') as f:
                json.dump(self.validation_results, f, indent=2)
            logger.info(f"Validation results exported to: {output_file}")
        except Exception as e:
            logger.error(f"Failed to export results: {e}")


def main():
    """Main function to run the installer validation."""
    print("Kamiwaza Installer Validation Test Suite")
    print("This tool validates the entire installer configuration without running anything.")
    print()
    
    # Initialize validator
    validator = InstallerValidator()
    
    # Run comprehensive validation
    results = validator.run_comprehensive_validation()
    
    # Print results
    validator.print_results()
    
    # Export results
    validator.export_results()
    
    # Return exit code based on results
    if results['errors']:
        sys.exit(1)
    elif results['warnings']:
        sys.exit(2)
    else:
        sys.exit(0)


if __name__ == "__main__":
    main() 