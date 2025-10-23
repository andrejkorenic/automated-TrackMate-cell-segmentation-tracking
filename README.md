<a id="readme-top"></a>

<!-- ABOUT THE PROJECT -->
<h1 align="center">Automated Cell Segmentation and Tracking<br/>Using TrackMate</h1>

[![Made with JavaScript](https://img.shields.io/badge/ImageJ2_Fiji-1.54p-yellow)](https://imagej.net/scripting/macro "Go to ImageJ Macro page") [![Made with Python](https://img.shields.io/badge/Python-2.5-yellow?logo=python&logoColor=white)](https://imagej.net/scripting/jython/examples "Go to ImageJ Jython Scripting page") [![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0) ![Version](https://img.shields.io/badge/Version-1.0.0-blue)


## 🔬 A Set of ImageJ Scripts for Automated Analysis of Fluorescent Microscopy Images: Cell Segmentation and Tracking with TrackMate

Save time analyzing thousands of cells with automated ImageJ scripts designed for fluorescent microscopy. These scripts leverage the power of TrackMate plugin to streamline cell segmentation and tracking, making it easier than ever to analyze large datasets efficiently. The process begins with a coarse-grained segmentation, followed by precise detection and tracking using cutting-edge algorithms available in TrackMate. Once calibrated, you can automate your workflow making it ideal for researchers handling large datasets in fluorescence microscopy.

<br/>

## 📌 Features

* **Automated Cell Analysis with TrackMate:** Streamline fluorescent microscopy workflows using the TrackMate plugin, featuring a suite of integrated methods for efficient segmentation and tracking.
* **Two-Step Segmentation & Tracking:**
    * Coarse segmentation for quick cell identification.
    * Fine tracking for precise cell detection and monitoring over time or in 3D.
* **Flexible Workflow:** TrackMate supports both temporal and spatial tracking, while for for 3D tracking, all z-axis frames are converted to time frames.
* **Efficient Dataset Analysis:** Save time by automating workflows for large microscopy datasets.
* **Post-Tracking Segmentation Refinement:** Enhance accuracy by fine-tuning segmentation using tracking data.

<br/>

### 📄 Citation

Please note that these scripts are based on a scientific publication. If you use them successfully for your research please be so kind to cite our work:

> Korenić, M., Korenić, A., Stamenković, V., Aysit, N. Andjus, P. (2025) The extracellular matrix glycoprotein tenascin-C supports the enriched environment-stimulated neurogenesis in the adult dentate gyrus of mice. *Biochem. Biophys. Res. Commun.* [https://doi.org/10.1016/j.bbrc.2025.152232](https://doi.org/10.1016/j.bbrc.2025.152232)
<p align="right"><a href="#readme-top">⏫</a></p>

<br/>

<!-- GETTING STARTED -->

## Getting Started

For instructions on setting up your environment, understanding the collection's organization, and effectively running the scripts, please refer to the *Installation*, *Files and Folders Structure*, and *Usage* sections below.

<br/>

### 🔧 Installation

1. **Download & Extract:** Download the entire repository from GitHub and extract the contents to a convenient directory on your Windows, Linux, or macOS system.
2. **Install ImageJ & Plugins:** These scripts rely on ImageJ/Fiji and several plugins.
    * Ensure you have a stable version of  [ImageJ2](https://imagej.net/software/imagej2) (including [Fiji](https://imagej.net/software/fiji)) installed. These scripts were tested and compatible with [Fiji 1.54p stable 20250808-2217](https://downloads.imagej.net/fiji/archive/stable/20250808-2217/), Java 1.8.0_452 (64-bit).
    * TrackMate v7 can be found at `Plugins → Tracking → TrackMate` since TrackMate resides in the `/jars` subfolder of the `Fiji.app` folder (i.e., `TrackMate-7.14.0.jar`)
    * Select `Help → Update...` from the menu to start the [updater](https://imagej.net/plugins/updater).
    * Click `Manage update sites` to [add](https://imagej.net/update-sites/following#add-update-sites) the following update site (if not already present):
        * TensorFlow 1.12.0 ([link](https://sites.imagej.net/tensorflow/))
        * StarDist 0.3.0
        * TrackMate-StarDist 1.2.0
        * CSBDeep 0.6.0 *(Probably optional)*
        * clij 1.8.1.1, clij2 2.5.3.5 *(Optional)*
        * 3D ImageJ Suite (3D Manager 4.1.7b) *(Optional)*
        * IJPB-plugins ([MorphoLibJ](https://imagej.net/plugins/morpholibj) library 1.6.4) *(Optional)*
    * Click `Apply changes` and restart ImageJ.

<br/>

### 📂 Files and Folders Structure

The following diagram illustrates how this collection's files and folders are organized, making it easier to navigate and understand its components:

```plaintext
/root
    ├── analysis_input/              # Input images for bulk analysis
    ├── analysis_output/             # Output from bulk analysis
    ├── calibration_input/           # Input images for setup
    ├── calibration_output/          # Output from setup process
    │   ├── 01_segmentation          # Segmentation results
    │   ├── 02_tracking              # Tracking results
    │   └── 03_final                 # Final results
    ├── setup_settings/              # Setup settings files (generated by setup.ijm)
    ├── setup.ijm                    # Main IJM script for automation procedure
    ├── automated_analysis.py        # Jython script for bulk analysis
    ├── auxiliary_scripts.ijm        # Auxiliary IJM scripts
    ├── README.md                    # Project overview
    └── LICENSE.txt                  # GPL-3.0 license
```

<br/>

### 📖 Usage

This collection of scripts is designed for ease of use, with built-in guidance through each step.

1. **Setup:** Use the `Plugins → Macros → Run...` command in Fiji to run `setup.ijm`. The script will guide you interactively, providing clear instructions at each stage of the setup process. This ensures you understand and configure the settings correctly.
2. **Saving Calibration Settings:** Upon completion, your customized setup parameters will be saved in both the `setup_settings` and the `setup_output` folder as part of the setup results. You can save these settings as `.zip` archive for future analysis runs on similar datasets.
3. **Bulk Analysis:** Once your setup is complete, run `automated_analysis.py`. This script automatically analyzes all image files located in the `analysis_input` folder using the previously saved parameters. Results will be generated and saved within the `analysis_output` folder.

<p align="right"><a href="#readme-top">⏫</a></p>

<br/>

<!-- CONTRIBUTING -->

## 📢 Found a Bug? Let Us Know!

We'll be grateful for your feedback and contributions! If you encounter any issues or have suggestions for improving this project, please take a moment to fill out our [issue reporting form](https://github.com/andrejkorenic/automated-TrackMate-cell-segmentation-tracking/issues). Your detailed reports will help us identify and resolve problems quickly.

Before submitting your issue, please consider the following points:

1. **Provide a clear description:** Briefly explain what's happening and why it's an issue.
2. **Reproduce the problem:** Outline the specific steps you took to encounter the issue. If applicable, include any sample code or data that can help us reproduce it.
3. **Expected vs. actual behavior:** Let us know what you expected to happen and what actually happened.
4. **Environment details:** Specify the versions of ImageJ/Fiji and all relevant plugins you're using.
5. **Error messages:** If there are any, copy and paste them into your report.

By including this information, you'll help us understand and address the issue more effectively. Thank you in advance for your thoughtful contributions!

<p align="right"><a href="#readme-top">⏫</a></p>

<br/>

<!-- ISSUES AND ROADMAP -->

## 🚩 Known Issues and Future Improvements

**Current Issues:**
- [x] ~~Users may encounter issues with TrackMate regarding saving and loading `xml` files containing analysis settings, especially with StarDist detector. This can lead to problems during automated analysis. We are actively working on resolving these issues and will provide updates as they become available.~~

**Future Improvements:**
- [ ] Implement automatic segmentation using one channel and tracking using a different channel.
- [ ] Automate measurement calculations based on final analyzed images, and save all analysis results in a user-friendly format, such as `csv`.
- [ ] Comprehensive tutorial documentation with step-by-step examples and screenshots.
- [ ] Leveraging GPU for image segmentation using StarDist.
- [ ] Improve batch mode invisibility...
- [ ] Improve error handling and logging for batch proccessing.

<p align="right"><a href="#readme-top">⏫</a></p>

<br/>

<!-- ACKNOWLEDGMENTS -->

## 🤝 Acknowledgments

We are deeply grateful to the following people and projects:

- The creators of [TrackMate](https://github.com/trackmate-sc/TrackMate) for developing and maintaining such an amazing ImageJ plugin. We would especially like to thank [Jean-Yves Tinevez](https://github.com/tinevez) for swift responses at [Scientific Community Image Forum](https://forum.image.sc/tag/trackmate) and constant dedication to the plugin development.
- The creators of the [TWOMBLI script](https://github.com/wershofe/TWOMBLI) for their clear documentation and the way the script is set up, which has been a great inspiration for this work.
- A big thank you to [Johanna M. Dela Cruz](https://www.youtube.com/@johanna.m.dela-cruz) for thorough YouTube tutorials, which have significantly helped us approach certain problems and task automation.

<p align="right"><a href="#readme-top">⏫</a></p>

<br/>

<!-- LICENCE -->

## 🏷️ Licence

This macro bundle is made available under the GPL-3.0 license (see [LICENSE.txt](LICENSE.txt) for the full text). The GPL-3.0 encourages open collaboration and knowledge sharing, allowing you to use, modify, and distribute this bundle freely as long as you adhere to its terms. We kindly request that you acknowledge the source and respect intellectual property rights when utilizing this macro bundle. Please note that a prior version, considered a working beta release, was also deposited with The Intellectual Property Office of the Republic of Serbia (No. A-0517/2014 9593).

<p align="right"><a href="#readme-top">⏫</a></p>
