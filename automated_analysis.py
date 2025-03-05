# File: ../automated_analysis.py
# Description: Fiji Jython script designed to automated analysis of multiple images.
# Author: Korenić Andrej, Ph.D, Research Associate
# Affiliation: Department for General Physiology and Biophysics,
#			   Institute for Physiology and Biochemistry "Ivan Djaja",
#			   University of Belgrade, Faculty of Biology, Serbia
# Created on: 2025-02-27
# Version: 1.0.0
# License: The Intellectual Property Office of the Republic of Serbia (No. A-0517/2014 9593)
# Dependencies: [coming soon...]
# Usage: use the Fiji editor's `Macros > Edit... > Run` command
# Revision History: N/A
# Contact: andrej.korenic@bio.bg.ac.rs

# Copyright (C) 2025 Korenić Andrej

#+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
#                 IMPORTS
#+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-

import sys
import os
import re
# import csv
# import time

from java.io import File

from ij import IJ, ImagePlus
from ij import WindowManager
from ij.io import FileSaver
# from ij.io import DirectoryChooser
# from ij.gui import WaitForUserDialog
# from ij.gui import GenericDialog

from ij.plugin import Duplicator, ImageCalculator
from ij.process import ImageConverter
# from ij.process import ImageProcessor

from fiji.plugin.trackmate import TrackMate
# from fiji.plugin.trackmate import Model
# from fiji.plugin.trackmate import SelectionModel
# from fiji.plugin.trackmate import Settings
from fiji.plugin.trackmate import Logger
from fiji.plugin.trackmate.io import TmXmlReader

# import fiji.plugin.trackmate.features.FeatureFilter as FeatureFilter
# from fiji.plugin.trackmate.stardist import StarDistCustomDetectorFactory
# from fiji.plugin.trackmate.detection import LogDetectorFactory
# from fiji.plugin.trackmate.tracking.jaqaman import SimpleSparseLAPTrackerFactory
# from fiji.plugin.trackmate.gui.displaysettings import DisplaySettingsIO
# from fiji.plugin.trackmate.visualization.hyperstack import HyperStackDisplayer
#from fiji.plugin.trackmate.visualization import SpotColorGeneratorPerTrackFeature
#from fiji.plugin.trackmate.visualization import PerTrackFeatureColorGenerator
from fiji.plugin.trackmate.action import LabelImgExporter
# from fiji.plugin.trackmate.action import CaptureOverlayAction
from fiji.plugin.trackmate.action.LabelImgExporter.LabelIdPainting import LABEL_IS_INDEX

# from inra.ijpb.watershed import MarkerControlledWatershedTransform2D
# from inra.ijpb.label import LabelImages



# We have to do the following to avoid errors with UTF8 chars generated in 
# TrackMate that will mess with our Fiji Jython.
reload(sys)
sys.setdefaultencoding('utf-8')

sep = os.sep

# Persistent global configuration dictionary
_global_config = {}


#+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
#               DEFINITIONS
#+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-

def get_mode():
    # Build the normalized path to the configuration file
    config_path = os.path.normpath(os.path.join(
        os.path.dirname(os.path.abspath(__file__)),
        "setup_settings/mode.txt"
    ))

    try:
        with open(config_path, 'r') as file:
            workingMode = file.read().strip()  # Read the content and strip any surrounding whitespace
            return workingMode
    except IOError:
        print("An error occurred while trying to read the file: {}".format(config_path))
        return None

def load_model_and_settings(file_path, settings):
    """
    Load a TrackMate model and its corresponding settings from an XML file.

    Parameters:
        file_path (str): The path to the XML file.

    Returns:
        tuple: A tuple containing the model and settings
    """
    reader = TmXmlReader(file_path)
    if not reader.isReadingOk():
        sys.exit(reader.getErrorMessage())

    # Retrieve the full model from the file
    model = reader.getModel()
    # model is a fiji.plugin.trackmate.Model
    
    # # A selection.
    # sm = SelectionModel( model )

    # # Read the display settings that was saved in the file.
    # ds = reader.getDisplaySettings()

    # # The viewer.
    # displayer =  HyperStackDisplayer( model, sm, ds ) 
    # displayer.render()

    # Load the source image associated with the model
    imp = reader.readImage()
    # # Swap Z and T dimensions if needed
    # dims = imp.getDimensions() # Default order: XYCZT
    # print(dims)
    # if (settings.get("swapDims") and dims[4] == 1):
    #     IJ.run(imp, "Re-order Hyperstack ...", "channels=[Channels (c)] slices=[Frames (t)] frames=[Slices (z)]");
    # else:
        # imp.show()

    # Build the settings object linked to the source image
    settings = reader.readSettings(imp)
    
    # Uncomment below to print the settings object (for debugging).
    # logger = Logger.IJ_LOGGER # We have to feed a logger to the reader.
    # logger.log(str('\n\nSETTINGS:\n'))
    # logger.log(str(settings))
    
    imp.show()
    
    # # With this, we can overlay the model and the source image:
    # displayer =  HyperStackDisplayer(model, sm, imp, ds)
    # displayer.render()

    return model, settings


# Define the function to process the image
def processSingleImage(inputDir, fileName, outputDir, segmentation_file, tracking_file, global_settings):
    """
    Open and process a single image for segmentation and tracking.
    
    Args:
        inputDir (str): Directory path containing the input image file
        fileName (str): Name of the input image file
        outputDir (str): Directory path where processed outputs will be saved
        seg_model (str): Path to the segmentation model
        seg_settings (dict): Dictionary of settings for the segmentation process
        track_model (str): Path to the tracking model
        track_settings (dict): Dictionary of settings for the tracking process

    Returns:
        str: Path to the processed image file or None if an error occurs
    """   
    # Open the image.
    imp = IJ.openImage(os.path.join(inputDir, fileName))

    # Split the title to remove the extension
    baseName = os.path.splitext(imp.getTitle())[0]
    
    if imp is None:
        print("Could not open image from file:", fileName)
    
    imp.setTitle("original_img")
    imp.show()
    
    # Swap Z and T dimensions if needed
    if (global_settings.get("swapDims")):
        IJ.run(imp, "Re-order Hyperstack ...", "channels=[Channels (c)] slices=[Frames (t)] frames=[Slices (z)]");
    
    imp = WindowManager.getImage("original_img")
    IJ.run(imp, "8-bit", "")
    
    # Load tracking model and settings
    model, settings = load_model_and_settings(segmentation_file, global_settings)
    
    # Instantiate TrackMate for segmentation
    trackmate = TrackMate(model, settings)

    # Execute (process) all.
    ok = trackmate.checkInput()
    if not ok:
        sys.exit(str(trackmate.getErrorMessage()))

    ok = trackmate.process()
    if not ok:
        sys.exit(str(trackmate.getErrorMessage()))
    
    # Export mask as 32-bit and 8-bit labels
    # Export mask: exportSpotsAsDots = False; exportTracksOnly = False
    LblImg = LabelImgExporter.createLabelImagePlus(trackmate, False, False, LABEL_IS_INDEX)
    LblImg.show()
    
    IJ.run(LblImg, "Duplicate...", "title=segmentation-mask-32bit duplicate")
    mask32bit = WindowManager.getImage("segmentation-mask-32bit")
    mask32bit.show()
    
    IJ.run(LblImg, "Duplicate...", "title=segmentation-mask-8bit duplicate")
    mask8bit = WindowManager.getImage("segmentation-mask-8bit")
    mask8bit.show()
    
    # Adjust display for 8-bit image
    ImageConverter.setDoScaling(True)
    IJ.run(mask8bit, "8-bit", "")
    IJ.run(mask8bit, "Max...", "value=1 stack")
    
    # Apply the mask to original image
    ic = ImageCalculator()
    masked = ic.run(imp, mask8bit, "Multiply create stack")
    masked.setTitle("segmented-original")
    masked.show()
    
    # Load tracking model and settings
    model, settings = load_model_and_settings(tracking_file, global_settings)
    
    # Instantiate TrackMate for tracking.
    trackmate = TrackMate(model, settings)

    # Execute (process) all.
    ok = trackmate.checkInput()
    if not ok:
        sys.exit(str(trackmate.getErrorMessage()))

    ok = trackmate.process()
    if not ok:
        sys.exit(str(trackmate.getErrorMessage()))
    
    # Export labeled image: exportSpotsAsDots = True, exportTracksOnly = True
    LblImg = LabelImgExporter.createLabelImagePlus(trackmate, True, True, LABEL_IS_INDEX)
    LblImg.show()

    IJ.run(LblImg, "Duplicate...", "title=tracked-segmented-original duplicate")
    tracked = WindowManager.getImage("tracked-segmented-original")
    tracked.show()
    
    # Swap back Z and T dimensions if needed
    if (global_settings.get("swapDims")):
        IJ.run(mask32bit, "Re-order Hyperstack ...", "channels=[Channels (c)] slices=[Frames (t)] frames=[Slices (z)]");
        IJ.run(tracked, "Re-order Hyperstack ...", "channels=[Channels (c)] slices=[Frames (t)] frames=[Slices (z)]");
    
    # Run refinement macro
    # Build the normalized path to the `refineMask.ijm`.
    macro_path = os.path.normpath(os.path.join(
        os.path.dirname(os.path.abspath(sys.argv[0])),
        "refineMask.ijm"
    ))
    macro_args = "segmentation-mask-32bit tracked-segmented-original"
    IJ.runMacroFile(macro_path, macro_args)
        
    imp = WindowManager.getImage("combinedMask")
    IJ.saveAs(imp, "Tiff", outputDir + "\\" + baseName)


def processBulkImages(mode, settings):
    """
    Processes multiple image files from an input directory by applying segmentation 
    and tracking models, then saves the processed images to an output directory.
    It leverages external configuration files for both segmentation and tracking parameters.
    This section of the code also verifies the accuracy of all input parameters.

    Args:
        settings (dict): Dictionary containing configuration parameters including:
            - analysisInputFolder: Path to the directory containing the input image files
            - analysisOutputFolder: Path to the directory where processed images will be stored
            - segmentationSettingsFile: File path to the XML configuration for segmentation
            - trackingSettingsFile: File path to the XML configuration for tracking
            - fileExtension: String indicating the file extension of images to process

    Returns:
        None
    """
    # Retrieve directory paths and XML configuration files from the settings.
    
    if (mode == "analysis"):
        # Get input directory path from settings
        inputDir = os.path.normpath(settings.get("analysisInputFolder"))
        if not inputDir:
            raise ValueError("Input directory is not specified in settings.")

        # Get output directory path from settings
        outputDir = os.path.normpath(settings.get("analysisOutputFolder"))
        if not outputDir:
            raise ValueError("Output directory is not specified in settings.")
    else:
        inputDir = os.path.normpath(settings.get("calibrationInputFolder"))
        if not inputDir:
            raise ValueError("Input directory is not specified in settings.")

        outputDir = os.path.normpath(os.path.join(settings.get("calibrationOutputFolder"), "03_final/"))
        if not outputDir:
            raise ValueError("Output directory is not specified in settings.")
        
    
    # Get file extension for image files to process
    fileExtension = settings.get("fileExtension")
    if not fileExtension:
        raise ValueError("File extension is not specified in settings.")

    # Load segmentation XML configuration file
    segmentation_file = File(os.path.normpath(settings.get("segmentationSettingsFile")))
    if not segmentation_file.exists():
        raise IOError("Segmentation settings file does not exist.")
    
    # Load tracking XML configuration file
    tracking_file = File(os.path.normpath(settings.get("trackingSettingsFile")))
    if not tracking_file.exists():
        raise IOError("Tracking settings file does not exist.")
    
    # Get list of image files to process based on the specified extension
    fileList = [f for f in os.listdir(inputDir) if f.endswith(fileExtension)]
    if not fileList:
        print("No images found with extension: {}".format(fileExtension))
        raise ValueError("No images found with given extension.")
    
    # Process each image file individually
    for _, fileName in enumerate(fileList):
        processSingleImage(inputDir, fileName, outputDir, segmentation_file, tracking_file, settings)
        IJ.run("Close All")


def load_config(file_name, config_dict=None):
    """
    Load configuration settings from a text file into a dictionary.
    
    This function searches for a configuration file in the same directory as the 
    currently executing script. The configuration file should be named using the 
    provided 'file_name' (without an extension) with a '.txt' suffix. The file is 
    expected to contain key-value pairs separated by an equals sign ('='), which 
    may be surrounded by spaces.
    
    If an existing dictionary is provided via 'config_dict', the loaded settings 
    will be appended to it. Otherwise, a persistent global dictionary is used to 
    accumulate settings across multiple calls.
    
    Parameters:
        file_name (str): The name of the configuration file (without the '.txt' extension).
        config_dict (dict, optional): An existing dictionary to update with the 
                                      configuration settings. Defaults to None, in 
                                      which case a persistent global dictionary is used.
    
    Returns:
        dict: A dictionary containing the configuration settings loaded from the file.
    
    Example:
        >>> settings = load_config("folder_structure")
        >>> settings = load_config("analysis_settings")
        >>> print(settings)  # Contains settings from both configuration files.
    
    Raises:
        IOError: If the configuration file cannot be read.
    """
    global _global_config
    # Use the global config if no dictionary is provided
    if config_dict is None:
        config_dict = _global_config

    # Build the normalized path to the configuration file
    config_path = os.path.normpath(os.path.join(
        os.path.dirname(os.path.abspath(sys.argv[0])),
        "setup_settings/" + file_name + ".txt"
    ))

    try:
        with open(config_path, 'r') as file:
            lines = file.readlines()
    except IOError:
        print("An error occurred while trying to read the file: {}".format(config_path))
        return config_dict

    # Process each line to update the configuration dictionary
    for line in lines:
        # Strip whitespace and skip empty or commented lines
        line = line.strip()
        if not line or line.startswith("#"):
            continue

        # Split on an equals sign with optional spaces around it (only once)
        parts = re.split(r'\s*=\s*', line, maxsplit=1)
        if len(parts) == 2:
            key, value = parts
            config_dict[key] = value
        else:
            print("Skipping invalid line: " + line)
    
    return config_dict



#+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
#                 MAIN
#+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-

def main():
    # Load settings from two files into the same dictionary
    settings = load_config("folder_structure")
    settings = load_config("analysis_settings")
    settings = load_config("mode")
    
    mode = settings.get("mode")

    if (mode != "calibration" and mode != "analysis"):
        raise ValueError("Invalid mode settings.")

    processBulkImages(mode, settings)

    IJ.run("Quit")
    
    return None

# Starting the main function
main()