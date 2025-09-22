#!/usr/bin/env python3
"""
Setup script for the Modern Actual Budget Dashboard
"""

import subprocess
import sys
import os
from pathlib import Path


def run_command(cmd, description):
    """Run a command and handle errors"""
    print(f"\n{description}...")
    try:
        result = subprocess.run(cmd, shell=True, check=True, capture_output=True, text=True)
        print(f"✓ {description} completed successfully")
        if result.stdout.strip():
            print(f"Output: {result.stdout.strip()}")
        return True
    except subprocess.CalledProcessError as e:
        print(f"✗ {description} failed: {e}")
        if e.stderr:
            print(f"Error: {e.stderr.strip()}")
        return False


def check_prerequisites():
    """Check if required tools are installed"""
    print("Checking prerequisites...")
    
    # Check Python version
    if sys.version_info < (3, 8):
        print("✗ Python 3.8 or higher is required")
        return False
    print(f"✓ Python {sys.version.split()[0]} found")
    
    # Check Node.js
    try:
        result = subprocess.run(['node', '--version'], capture_output=True, text=True, check=True)
        node_version = result.stdout.strip()
        print(f"✓ Node.js {node_version} found")
        
        # Check if version is >= 18
        version_num = int(node_version.replace('v', '').split('.')[0])
        if version_num < 18:
            print("⚠ Node.js 18 or higher is recommended for the Actual Budget API")
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("✗ Node.js not found. Please install Node.js 18 or higher")
        return False
    
    # Check npm
    try:
        subprocess.run(['npm', '--version'], capture_output=True, text=True, check=True)
        print("✓ npm found")
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("✗ npm not found. Please install npm")
        return False
    
    return True


def setup_python_environment():
    """Set up Python environment and dependencies"""
    print("\nSetting up Python environment...")
    
    # Upgrade pip
    if not run_command(f"{sys.executable} -m pip install --upgrade pip", 
                      "Upgrading pip"):
        return False
    
    # Install Python dependencies
    if not run_command(f"{sys.executable} -m pip install -r requirements.txt", 
                      "Installing Python dependencies"):
        return False
    
    return True


def setup_node_environment():
    """Set up Node.js environment and dependencies"""
    print("\nSetting up Node.js environment...")
    
    # Install Node.js dependencies
    if not run_command("npm install", "Installing Node.js dependencies"):
        return False
    
    # Make the bridge script executable
    bridge_path = Path("actual_api_bridge.js")
    if bridge_path.exists():
        try:
            os.chmod(bridge_path, 0o755)
            print("✓ Made API bridge script executable")
        except OSError as e:
            print(f"⚠ Could not make bridge script executable: {e}")
    
    return True


def create_env_file():
    """Create .env file from template if it doesn't exist"""
    env_file = Path(".env")
    template_file = Path(".env.template")
    
    if not env_file.exists() and template_file.exists():
        print("\nCreating .env file from template...")
        try:
            with open(template_file, 'r') as src, open(env_file, 'w') as dst:
                dst.write(src.read())
            print("✓ Created .env file from template")
            print("⚠ Please edit .env with your Actual Budget server configuration")
            return True
        except OSError as e:
            print(f"✗ Could not create .env file: {e}")
            return False
    elif env_file.exists():
        print("✓ .env file already exists")
        return True
    else:
        print("⚠ No .env.template found, skipping .env creation")
        return True


def test_setup():
    """Test the setup by running basic API calls"""
    print("\nTesting setup...")
    
    # Test Node.js bridge
    if run_command("node actual_api_bridge.js --help", 
                  "Testing Node.js API bridge"):
        print("✓ Node.js bridge is working")
    else:
        print("⚠ Node.js bridge test failed (this is expected if you haven't configured .env yet)")
    
    # Test Python imports
    try:
        from actual_api_client import ActualBudgetClient
        from dashboard.data_processor import ActualDataProcessor
        print("✓ Python modules import successfully")
        return True
    except ImportError as e:
        print(f"✗ Python import test failed: {e}")
        return False


def main():
    """Main setup function"""
    print("🏦 Modern Actual Budget Dashboard Setup")
    print("=" * 50)
    
    success = True
    
    # Check prerequisites
    if not check_prerequisites():
        print("\n❌ Prerequisites check failed. Please install required tools.")
        sys.exit(1)
    
    # Setup Python environment
    if not setup_python_environment():
        print("\n❌ Python environment setup failed.")
        success = False
    
    # Setup Node.js environment  
    if not setup_node_environment():
        print("\n❌ Node.js environment setup failed.")
        success = False
    
    # Create environment file
    if not create_env_file():
        print("\n⚠ Environment file setup had issues.")
    
    # Test setup
    if not test_setup():
        print("\n⚠ Setup tests had issues, but installation may still work.")
    
    # Final status
    print("\n" + "=" * 50)
    if success:
        print("✅ Setup completed successfully!")
        print("\nNext steps:")
        print("1. Edit .env with your Actual Budget server configuration")
        print("2. Ensure your Actual Budget server is running")
        print("3. Run: python app.py")
        print("4. Open http://127.0.0.1:8050 in your browser")
    else:
        print("❌ Setup completed with errors. Please check the output above.")
        sys.exit(1)


if __name__ == "__main__":
    main()
