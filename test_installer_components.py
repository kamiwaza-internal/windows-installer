#!/usr/bin/env python3
"""
Kamiwaza Installer Component Test Suite
Tests specific installer components without running anything.
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

class InstallerComponentTester:
    """Tests specific installer components for validation."""
    
    def __init__(self, wxs_file_path: str = "installer.wxs"):
        self.wxs_file_path = wxs_file_path
        self.tree = None
        self.root = None
        self.test_results = {
            'wsl_integration': {'passed': [], 'failed': [], 'status': 'UNKNOWN'},
            'gpu_scripts': {'passed': [], 'failed': [], 'status': 'UNKNOWN'},
            'file_placements': {'passed': [], 'failed': [], 'status': 'UNKNOWN'},
            'execution_sequence': {'passed': [], 'failed': [], 'status': 'UNKNOWN'},
            'registry_entries': {'passed': [], 'failed': [], 'status': 'UNKNOWN'},
            'cleanup_actions': {'passed': [], 'failed': [], 'status': 'UNKNOWN'}
        }
        
    def load_wxs_file(self) -> bool:
        """Load and parse the WiX file."""
        try:
            if not os.path.exists(self.wxs_file_path):
                logger.error(f"WiX file not found: {self.wxs_file_path}")
                return False
                
            self.tree = ET.parse(self.wxs_file_path)
            self.root = self.tree.getroot()
            logger.info(f"Successfully loaded WiX file: {self.wxs_file_path}")
            return True
        except Exception as e:
            logger.error(f"Failed to parse WiX file: {e}")
            return False
    
    def test_wsl_integration(self) -> None:
        """Test WSL integration components."""
        logger.info("Testing WSL integration components...")
        
        # Check WSL memory configuration
        wsl_memory_prop = self.root.find('.//Property[@Id="WSLMEMORY"]')
        if wsl_memory_prop is not None:
            default_value = wsl_memory_prop.get('Value')
            if default_value == '14GB':
                self.test_results['wsl_integration']['passed'].append("WSL memory default: 14GB")
            else:
                self.test_results['wsl_integration']['failed'].append(f"Unexpected WSL memory default: {default_value}")
        else:
            self.test_results['wsl_integration']['failed'].append("WSLMEMORY property not found")
        
        # Check WSL configuration script
        wsl_script = self.root.find('.//File[@Name="configure_wsl_memory.ps1"]')
        if wsl_script is not None:
            source = wsl_script.get('Source')
            if source and os.path.exists(source):
                self.test_results['wsl_integration']['passed'].append("WSL memory config script found and source exists")
            else:
                self.test_results['wsl_integration']['failed'].append(f"WSL script source not found: {source}")
        else:
            self.test_results['wsl_integration']['failed'].append("WSL memory configuration script not included")
        
        # Check WSL cleanup scripts
        wsl_cleanup_scripts = ['cleanup_wsl_kamiwaza.ps1', 'cleanup_installs.bat']
        for script in wsl_cleanup_scripts:
            script_elem = self.root.find(f'.//File[@Name="{script}"]')
            if script_elem is not None:
                self.test_results['wsl_integration']['passed'].append(f"WSL cleanup script included: {script}")
            else:
                self.test_results['wsl_integration']['failed'].append(f"WSL cleanup script not found: {script}")
        
        # Set status
        if self.test_results['wsl_integration']['failed']:
            self.test_results['wsl_integration']['status'] = 'FAILED'
        else:
            self.test_results['wsl_integration']['status'] = 'PASSED'
    
    def test_gpu_scripts(self) -> None:
        """Test GPU detection and setup scripts."""
        logger.info("Testing GPU scripts...")
        
        # Check GPU detection scripts
        gpu_detection_scripts = ['detect_gpu.ps1', 'detect_gpu_cmd.bat']
        for script in gpu_detection_scripts:
            script_elem = self.root.find(f'.//File[@Name="{script}"]')
            if script_elem is not None:
                source = script_elem.get('Source')
                if source and os.path.exists(source):
                    self.test_results['gpu_scripts']['passed'].append(f"GPU detection script found: {script}")
                else:
                    self.test_results['gpu_scripts']['failed'].append(f"GPU script source not found: {script} -> {source}")
            else:
                self.test_results['gpu_scripts']['failed'].append(f"GPU detection script not included: {script}")
        
        # Check GPU setup scripts
        gpu_setup_scripts = ['setup_nvidia_gpu.sh', 'setup_intel_arc_gpu.sh', 'setup_intel_integrated_gpu.sh']
        for script in gpu_setup_scripts:
            script_elem = self.root.find(f'.//File[@Name="{script}"]')
            if script_elem is not None:
                source = script_elem.get('Source')
                if source and os.path.exists(source):
                    self.test_results['gpu_scripts']['passed'].append(f"GPU setup script found: {script}")
                else:
                    self.test_results['gpu_scripts']['failed'].append(f"GPU setup script source not found: {script} -> {source}")
            else:
                self.test_results['gpu_scripts']['failed'].append(f"GPU setup script not included: {script}")
        
        # Check GPU detection custom actions
        gpu_actions = ['DetectGPUCmd', 'DetectGPU']
        for action_id in gpu_actions:
            action = self.root.find(f'.//CustomAction[@Id="{action_id}"]')
            if action is not None:
                self.test_results['gpu_scripts']['passed'].append(f"GPU detection action configured: {action_id}")
            else:
                self.test_results['gpu_scripts']['failed'].append(f"GPU detection action not found: {action_id}")
        
        # Set status
        if self.test_results['gpu_scripts']['failed']:
            self.test_results['gpu_scripts']['status'] = 'FAILED'
        else:
            self.test_results['gpu_scripts']['status'] = 'PASSED'
    
    def test_file_placements(self) -> None:
        """Test file placement and directory structure."""
        logger.info("Testing file placements...")
        
        # Check main installation directory structure
        install_folder = self.root.find('.//Directory[@Id="INSTALLFOLDER"]')
        if install_folder is not None:
            self.test_results['file_placements']['passed'].append("Main installation directory configured")
        else:
            self.test_results['file_placements']['failed'].append("Main installation directory not found")
        
        # Check Python runtime directory
        python_folder = install_folder.find('.//Directory[@Id="PYTHONFOLDER"]') if install_folder is not None else None
        if python_folder is not None:
            self.test_results['file_placements']['passed'].append("Python runtime directory configured")
        else:
            self.test_results['file_placements']['failed'].append("Python runtime directory not found")
        
        # Check all required files are included
        required_files = [
            'kamiwaza_headless_installer.py',
            'run_kamiwaza.bat',
            'config.yaml',
            'start_platform.bat',
            'kamiwaza_start.bat',
            'kamiwaza_stop.bat'
        ]
        
        main_component = self.root.find('.//Component[@Id="KamiwazaInstallerFiles"]')
        if main_component is not None:
            for required_file in required_files:
                file_elem = main_component.find(f'.//File[@Name="{required_file}"]')
                if file_elem is not None:
                    source = file_elem.get('Source')
                    if source and os.path.exists(source):
                        self.test_results['file_placements']['passed'].append(f"Required file found: {required_file}")
                    else:
                        self.test_results['file_placements']['failed'].append(f"Required file source not found: {required_file} -> {source}")
                else:
                    self.test_results['file_placements']['failed'].append(f"Required file not included: {required_file}")
        else:
            self.test_results['file_placements']['failed'].append("Main component not found")
        
        # Set status
        if self.test_results['file_placements']['failed']:
            self.test_results['file_placements']['status'] = 'FAILED'
        else:
            self.test_results['file_placements']['status'] = 'PASSED'
    
    def test_execution_sequence(self) -> None:
        """Test custom action execution sequence."""
        logger.info("Testing execution sequence...")
        
        install_sequence = self.root.find('.//InstallExecuteSequence')
        if install_sequence is None:
            self.test_results['execution_sequence']['failed'].append("InstallExecuteSequence not found")
            return
        
        # Check that all critical custom actions are in sequence
        critical_actions = [
            'ReservePorts',
            'RunKamiwazaInstaller',
            'DetectGPU',
            'SetupAutostartRegistry',
            'InstallGUIManager'
        ]
        
        sequence_actions = install_sequence.findall('.//Custom')
        sequence_action_ids = [action.get('Action') for action in sequence_actions]
        
        for action_id in critical_actions:
            if action_id in sequence_action_ids:
                self.test_results['execution_sequence']['passed'].append(f"Critical action in sequence: {action_id}")
            else:
                self.test_results['execution_sequence']['failed'].append(f"Critical action not in sequence: {action_id}")
        
        # Check action order (basic validation)
        if len(sequence_actions) > 0:
            self.test_results['execution_sequence']['passed'].append(f"Execution sequence has {len(sequence_actions)} actions")
        else:
            self.test_results['execution_sequence']['failed'].append("No custom actions in execution sequence")
        
        # Set status
        if self.test_results['execution_sequence']['failed']:
            self.test_results['execution_sequence']['status'] = 'FAILED'
        else:
            self.test_results['execution_sequence']['status'] = 'PASSED'
    
    def test_registry_entries(self) -> None:
        """Test registry entry configuration."""
        logger.info("Testing registry entries...")
        
        # Check main registry value
        main_registry = self.root.find('.//RegistryValue[@Name="installed"]')
        if main_registry is not None:
            self.test_results['registry_entries']['passed'].append("Main registry entry configured")
        else:
            self.test_results['registry_entries']['failed'].append("Main registry entry not found")
        
        # Check registry cleanup on uninstall
        registry_cleanup = self.root.find('.//RegistryKey[@ForceDeleteOnUninstall="yes"]')
        if registry_cleanup is not None:
            self.test_results['registry_entries']['passed'].append("Registry cleanup on uninstall configured")
        else:
            self.test_results['registry_entries']['failed'].append("Registry cleanup on uninstall not configured")
        
        # Check autostart registry setup
        autostart_action = self.root.find('.//CustomAction[@Id="SetupAutostartRegistry"]')
        if autostart_action is not None:
            self.test_results['registry_entries']['passed'].append("Autostart registry setup action configured")
        else:
            self.test_results['registry_entries']['failed'].append("Autostart registry setup action not found")
        
        # Set status
        if self.test_results['registry_entries']['failed']:
            self.test_results['registry_entries']['status'] = 'FAILED'
        else:
            self.test_results['registry_entries']['status'] = 'PASSED'
    
    def test_cleanup_actions(self) -> None:
        """Test cleanup and uninstall actions."""
        logger.info("Testing cleanup actions...")
        
        # Check file removal actions
        remove_files = self.root.findall('.//RemoveFile')
        if remove_files:
            self.test_results['cleanup_actions']['passed'].append(f"File cleanup actions configured: {len(remove_files)} actions")
        else:
            self.test_results['cleanup_actions']['failed'].append("No file cleanup actions configured")
        
        # Check folder removal
        remove_folder = self.root.find('.//RemoveFolder')
        if remove_folder is not None:
            self.test_results['cleanup_actions']['passed'].append("Folder cleanup on uninstall configured")
        else:
            self.test_results['cleanup_actions']['failed'].append("Folder cleanup on uninstall not configured")
        
        # Check comprehensive cleanup custom action
        comprehensive_cleanup = self.root.find('.//CustomAction[@Id="ComprehensiveCleanup"]')
        if comprehensive_cleanup is not None:
            self.test_results['cleanup_actions']['passed'].append("Comprehensive cleanup action configured")
        else:
            self.test_results['cleanup_actions']['failed'].append("Comprehensive cleanup action not found")
        
        # Check port release on uninstall
        port_release = self.root.find('.//CustomAction[@Id="ReleasePorts"]')
        if port_release is not None:
            self.test_results['cleanup_actions']['passed'].append("Port release on uninstall configured")
        else:
            self.test_results['cleanup_actions']['failed'].append("Port release on uninstall not found")
        
        # Set status
        if self.test_results['cleanup_actions']['failed']:
            self.test_results['cleanup_actions']['status'] = 'FAILED'
        else:
            self.test_results['cleanup_actions']['status'] = 'PASSED'
    
    def run_all_tests(self) -> Dict:
        """Run all component tests."""
        logger.info("Starting installer component tests...")
        
        if not self.load_wxs_file():
            return self.test_results
        
        # Run all tests
        test_methods = [
            self.test_wsl_integration,
            self.test_gpu_scripts,
            self.test_file_placements,
            self.test_execution_sequence,
            self.test_registry_entries,
            self.test_cleanup_actions
        ]
        
        for method in test_methods:
            try:
                method()
            except Exception as e:
                logger.error(f"Test method {method.__name__} failed: {e}")
                # Mark the test as failed
                test_name = method.__name__.replace('test_', '')
                if test_name in self.test_results:
                    self.test_results[test_name]['failed'].append(f"Test execution failed: {e}")
                    self.test_results[test_name]['status'] = 'FAILED'
        
        # Generate overall summary
        total_tests = len(self.test_results)
        passed_tests = sum(1 for test in self.test_results.values() if test['status'] == 'PASSED')
        failed_tests = sum(1 for test in self.test_results.values() if test['status'] == 'FAILED')
        
        self.test_results['summary'] = {
            'total_tests': total_tests,
            'passed_tests': passed_tests,
            'failed_tests': failed_tests,
            'success_rate': (passed_tests / total_tests * 100) if total_tests > 0 else 0
        }
        
        logger.info("All component tests completed")
        return self.test_results
    
    def print_test_results(self) -> None:
        """Print test results in a formatted way."""
        results = self.test_results
        
        print("\n" + "="*80)
        print("KAMIWAZA INSTALLER COMPONENT TEST RESULTS")
        print("="*80)
        
        if 'summary' in results:
            summary = results['summary']
            print(f"\nOVERALL SUMMARY:")
            print(f"  Total Tests: {summary['total_tests']}")
            print(f"  Passed: {summary['passed_tests']}")
            print(f"  Failed: {summary['failed_tests']}")
            print(f"  Success Rate: {summary['success_rate']:.1f}%")
        
        # Print results for each test category
        for test_category, test_result in results.items():
            if test_category == 'summary':
                continue
                
            print(f"\n{test_category.upper().replace('_', ' ')}:")
            status_icon = "[OK]" if test_result['status'] == 'PASSED' else "[FAIL]"
            print(f"  Status: {status_icon} {test_result['status']}")
            
            if test_result['passed']:
                print(f"  Passed ({len(test_result['passed'])}):")
                for passed in test_result['passed'][:5]:  # Show first 5
                    print(f"    • {passed}")
                if len(test_result['passed']) > 5:
                    print(f"    ... and {len(test_result['passed']) - 5} more")
            
            if test_result['failed']:
                print(f"  Failed ({len(test_result['failed'])}):")
                for failed in test_result['failed']:
                    print(f"    • {failed}")
        
        print("\n" + "="*80)
        
        # Overall status
        if 'summary' in results:
            summary = results['summary']
            if summary['failed_tests'] > 0:
                print("[FAIL] SOME TESTS FAILED - Review failed components")
            else:
                print("[OK] ALL TESTS PASSED - Installer components validated")
        
        print("="*80 + "\n")
    
    def export_results(self, output_file: str = "installer_component_test_results.json") -> None:
        """Export test results to JSON file."""
        try:
            with open(output_file, 'w') as f:
                json.dump(self.test_results, f, indent=2)
            logger.info(f"Test results exported to: {output_file}")
        except Exception as e:
            logger.error(f"Failed to export results: {e}")


def main():
    """Main function to run the installer component tests."""
    print("Kamiwaza Installer Component Test Suite")
    print("This tool tests specific installer components without running anything.")
    print()
    
    # Initialize tester
    tester = InstallerComponentTester()
    
    # Run all tests
    results = tester.run_all_tests()
    
    # Print results
    tester.print_test_results()
    
    # Export results
    tester.export_results()
    
    # Return exit code based on results
    if 'summary' in results:
        summary = results['summary']
        if summary['failed_tests'] > 0:
            sys.exit(1)
        else:
            sys.exit(0)
    else:
        sys.exit(1)


if __name__ == "__main__":
    main() 