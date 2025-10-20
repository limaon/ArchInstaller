# ArchInstaller Web Assistant

## Project Overview

This is a web-based documentation viewer and configuration generator for the ArchInstaller project. The original ArchInstaller is a collection of bash scripts designed to automate the installation of Arch Linux on bare metal or virtual machines.

**Purpose:** Since the original installation scripts cannot be executed in the Replit environment (they require booting from an Arch Linux ISO and formatting physical disks), this web application provides a useful interface to:
1. Browse and read the installation documentation
2. Generate custom configuration files for Arch Linux installations
3. Explore available desktop environments and package options

## Current State

The project is fully functional and includes:
- ✅ Flask web application serving on port 5000
- ✅ Documentation viewer for browsing markdown reference files
- ✅ Interactive configuration generator
- ✅ Clean, responsive UI with navigation
- ✅ Deployment configuration using Gunicorn
- ✅ Python 3.11 with Flask, Markdown2, and Pygments

## Project Architecture

### Backend (Flask)
- **app.py** - Main Flask application with routes for:
  - Home page
  - Documentation browser and viewer
  - Configuration generator
  - README viewer

### Frontend
- **templates/** - Jinja2 HTML templates
  - base.html - Base layout with navigation
  - index.html - Home page with overview
  - docs.html - Documentation list
  - doc_view.html - Individual document viewer
  - config.html - Interactive config generator
- **static/css/** - Styling
  - style.css - Main stylesheet with responsive design
- **static/js/** - Client-side functionality
  - config.js - Configuration form handling and download

### Original ArchInstaller Files
- **scripts/** - Bash installation scripts (for reference only)
- **packages/** - JSON files defining package groups
- **configs/** - Sample configuration files
- **docs/** - Markdown documentation

## Recent Changes (October 20, 2025)

- Created Flask web application to make the project functional in Replit
- Implemented documentation viewer using markdown2 and pygments
- Built interactive configuration generator that reads package JSON files
- Created responsive UI with clean navigation
- Set up workflow to run Flask dev server on port 5000
- Configured deployment with Gunicorn for production use
- Added Python-specific entries to .gitignore

## How to Use

### Development
The Flask server runs automatically on port 5000. Changes to Python files will trigger automatic reloads.

### Production Deployment
The project is configured to deploy using Gunicorn as an autoscale deployment, which is suitable for this stateless web application.

### Features

1. **Documentation Browser** - View all reference documentation for the ArchInstaller scripts
2. **README Viewer** - Read the main project README with formatted markdown
3. **Config Generator** - Create custom setup.conf files by filling out a form with:
   - Username and hostname
   - Timezone and keymap
   - Desktop environment selection
   - AUR helper choice
   - Installation type (full/minimal)

## Important Notes

- This web application is a **viewer and helper tool** for the ArchInstaller project
- The actual installation scripts **cannot run** in Replit
- To use the actual installer, you must:
  1. Download Arch Linux ISO
  2. Boot from the ISO on physical hardware or a VM
  3. Clone the repository and run ./archinstall.sh
- This web interface helps you understand the installer and prepare configuration files

## Technology Stack

- **Backend:** Python 3.11, Flask 3.1.2
- **Templating:** Jinja2
- **Markdown Processing:** markdown2 with Pygments for syntax highlighting
- **Production Server:** Gunicorn 23.0.0
- **Frontend:** Vanilla JavaScript, CSS3
- **Environment:** Replit NixOS

## User Preferences

None specified yet.

## Dependencies

All dependencies are managed via uv and defined in pyproject.toml:
- flask
- markdown2
- pygments
- gunicorn
