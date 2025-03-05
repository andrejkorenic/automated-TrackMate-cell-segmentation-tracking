# File: ../automated_analysis.py
# Description: ImageJ Jython script for automating the analysis of multiple images.
# Author: Korenić Andrej, Ph.D, Research Associate
# Affiliation: Department for General Physiology and Biophysics,
#			   Institute for Physiology and Biochemistry "Ivan Djaja",
#			   Faculty of Biology, University of Belgrade, Serbia
# Created on: 2025-04-17
# Version: 1.0.0
# License: GPL-3.0 & The Intellectual Property Office of the Republic of Serbia (No. A-0517/2014 9593)
# Dependencies: ImageJ/Fiji 1.54p, Java 1.8.0_322 (64-bit), TrackMate 7.14.0
# Usage: use `Plugins -> Macros -> Edit...` menu command or drag&drop file

# Copyright (C) 2025 Korenić Andrej
# https://github.com/andrejkorenic/automated-TrackMate-cell-segmentation-tracking

#+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
#                 IMPORTS
#+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-

import sys
import os
import re

from java.io import File # type: ignore

from ij import IJ # type: ignore
from ij import WindowManager # type: ignore

from ij.plugin import ImageCalculator # type: ignore
from ij.process import ImageConverter # type: ignore

from fiji.plugin.trackmate import TrackMate # type: ignore
from fiji.plugin.trackmate import Logger # type: ignore
from fiji.plugin.trackmate.io import TmXmlReader # type: ignore
from fiji.plugin.trackmate import Settings # type: ignore
from fiji.plugin.trackmate import Model # type: ignore

from fiji.plugin.trackmate.action import LabelImgExporter # type: ignore
from fiji.plugin.trackmate.action.LabelImgExporter.LabelIdPainting import LABEL_IS_INDEX # type: ignore


# We have to do the following to avoid errors with UTF8 chars generated in 
# TrackMate that will mess with our Fiji Jython.
reload(sys) # type: ignore
sys.setdefaultencoding('utf-8') # type: ignore

sep = os.sep # gets "\" on Windows and "/" on Unix

# Global configuration dictionary
_global_config = {}


#+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
#               FUNCTIONS
#+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-


def get_mode():
    """Retrieves the operating mode from a configuration file.

    This function reads the `mode` value from a configuration file located in 
    the `setup_settings` directory relative to the current script. 

    Returns:
        str: The operating mode specified in the file, or None if an error occurs.

    Raises:
        IOError
    """
    
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


def set_mode(modeStr):
    """Writes the operating mode to a configuration file.

    This function writes the `mode` value to a configuration file located in 
    the `setup_settings` directory relative to the current script. 

    Raises:
        IOError
    """
    
    # Build the normalized path to the configuration file
    config_path = os.path.normpath(os.path.join(
        os.path.dirname(os.path.abspath(__file__)),
        "setup_settings/mode.txt"
    ))

    try:
        with open(config_path, 'w') as file:
            file.write("mode={}".format(modeStr))
    except IOError:
        print("An error occurred while trying to write the file: {}".format(config_path))            


def load_model_and_settings(file_path):
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
    model = reader.getModel() # model is a fiji.plugin.trackmate.Model

    # Load the source image associated with the model
    imp = reader.readImage()

    # Build the settings object linked to the source image
    settings = reader.readSettings(imp)
    
    # # Uncomment below to print the settings object (for debugging).
    # logger = Logger.IJ_LOGGER # We have to feed a logger to the reader.
    # logger.log(str('\n\nSETTINGS:\n'))
    # logger.log(str(settings))
    
    imp.show()

    return model, settings


def processSingleImage(inputDir, fileName, outputDir, segmentation_file, tracking_file, global_settings):
    """Processes a single image for segmentation and tracking.

    This function takes an input image, loads a segmentation model and tracking model 
    from specified files, performs segmentation and tracking using the TrackMate plugin, 
    and saves the results as a TIFF image in the output directory.

    Parameters:
        inputDir (str): The directory containing the input image.
        fileName (str): The name of the input image file.
        outputDir (str): The directory to save the processed image.
        segmentation_file (str): Path to the file containing the segmentation model settings.
        tracking_file (str): Path to the file containing the tracking model settings.
        global_settings (dict): A dictionary containing global settings for the processing.

    Returns:
        None 
    """
    
    # Build the normalized path to the `auxiliary_scripts.ijm`.
    macro_path = os.path.normpath(os.path.join(
        os.path.dirname(os.path.abspath(sys.argv[0])),
        "auxiliary_scripts.ijm"
    ))
    
    # Open the image.
    original_img = IJ.openImage(os.path.join(inputDir, fileName))

    # Split the title to remove the extension
    baseName = os.path.splitext(original_img.getTitle())[0]
    
    if original_img is None:
        print("Could not open image from file:", fileName)
    original_img.show()
    original_img.setTitle("original_img")
    
    # Run fix stack macro
    IJ.runMacroFile(macro_path, "fixStack in original_img")
    
    # Enhance contrast
    contrastSaturation = str(global_settings.get("contrastSaturation"))
    contrastSaturationString = "saturated=" + contrastSaturation + " process_all use"
                             # "saturated=" + contrastSaturation + " normalize process_all use"
    IJ.run("Enhance Contrast...", contrastSaturationString)
    
    # Resize image if needed
    resizeMe = int(global_settings.get("resizeMe")) == 1
    
    if (resizeMe):
        resizeDim = str(global_settings.get("resizeDim"))
        newSize = str(global_settings.get("newSize"))
        original_dims = resize_image(original_img, resizeDim, newSize)
    
    original_img = WindowManager.getImage("original_img")
    ImageConverter.setDoScaling(True)
    IJ.run(original_img, "8-bit", "")

    # Load tracking model and settings
    model, settings = load_model_and_settings(segmentation_file)
    
    # Instantiate TrackMate for segmentation
    transferredSettings = settings.copyOn(original_img)
    model = Model()
    trackmate = TrackMate(model, transferredSettings)

    # Execute (process) all
    ok = trackmate.checkInput()
    if not ok:
        print(str(trackmate.getErrorMessage()))
        return

    ok = trackmate.process()
    if not ok:
        print(str(trackmate.getErrorMessage()))
        return
    
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
    original_img = WindowManager.getImage("original_img")
    mask8bit = WindowManager.getImage("segmentation-mask-8bit")
    masked = ImageCalculator.run(original_img, mask8bit, "Multiply create stack")
    masked.setTitle("segmented-original")
    masked.show()
    
    # Load tracking model and settings
    model, settings = load_model_and_settings(tracking_file)

    # Instantiate TrackMate for tracking
    transferredSettings = settings.copyOn(masked)
    model = Model()
    trackmate = TrackMate(model, transferredSettings)

    # Execute (process) all
    ok = trackmate.checkInput()
    if not ok:
        print(str(trackmate.getErrorMessage()))
        return

    ok = trackmate.process()
    if not ok:
        print(str(trackmate.getErrorMessage()))
        return
    
    # Export labeled image: exportSpotsAsDots = True, exportTracksOnly = True
    LblImg = LabelImgExporter.createLabelImagePlus(trackmate, True, True, LABEL_IS_INDEX)
    LblImg.show()

    IJ.run(LblImg, "Duplicate...", "title=tracked-segmented-original duplicate")
    tracked = WindowManager.getImage("tracked-segmented-original")
    tracked.show()
    
    # Run fix stack macro
    IJ.runMacroFile(macro_path, "fixStack out segmentation-mask-32bit")
    IJ.runMacroFile(macro_path, "fixStack out tracked-segmented-original")
    
    # Run refinement macro
    IJ.runMacroFile(macro_path, "refineMask segmentation-mask-32bit tracked-segmented-original")

    imp = WindowManager.getImage("combinedMask")

    # Revert image resize, if needed
    if (resizeMe):
        revert_image_size(original_dims)
    
    # Save final output image
    IJ.saveAs(imp, "Tiff", outputDir + "\\" + baseName)


def processBulkImages(mode, settings):
    """Processes multiple images in bulk based on provided mode and settings.

    This function takes a processing mode ("analysis" or "calibration") and a dictionary of settings. 
    It retrieves input and output directory paths, file extension, segmentation and tracking configuration files from the settings. 
    Then it processes each image file individually, calling the `processSingleImage` function for each one.

    Parameters:
        mode (str): The processing mode ("analysis" or "calibration").
        settings (dict): A dictionary containing configuration settings.

    Raises:
        ValueError: If required settings are missing or incorrect.
        IOError: If segmentation or tracking configuration files do not exist.
    """

    # Retrieve directory paths and XML configuration files from the settings.
    
    if (mode == "analysis"):
        # Get input directory path from settings
        inputDir = os.path.normpath(str(settings.get("analysisInputFolder")))
        if not inputDir:
            raise ValueError("Input directory is not specified in settings.")

        # Get output directory path from settings
        outputDir = os.path.normpath(str(settings.get("analysisOutputFolder")))
        if not outputDir:
            raise ValueError("Output directory is not specified in settings.")
    else:
        inputDir = os.path.normpath(str(settings.get("calibrationInputFolder")))
        if not inputDir:
            raise ValueError("Input directory is not specified in settings.")

        outputDir = os.path.normpath(os.path.join(str(settings.get("calibrationOutputFolder")), "03_final/"))
        if not outputDir:
            raise ValueError("Output directory is not specified in settings.")
        
    # Get file extension for image files to process
    fileExtension = settings.get("fileExtension")
    if not fileExtension:
        raise ValueError("File extension is not specified in settings.")

    # Load segmentation XML configuration file
    segmentation_file = File(os.path.normpath(str(settings.get("segmentationSettingsFile"))))
    if not segmentation_file.exists():
        raise IOError("Segmentation settings file does not exist.")
    
    # Load tracking XML configuration file
    tracking_file = File(os.path.normpath(str(settings.get("trackingSettingsFile"))))
    if not tracking_file.exists():
        raise IOError("Tracking settings file does not exist.")
    
    # Get list of image files to process based on the specified extension
    fileList = [f for f in os.listdir(inputDir) if f.endswith(fileExtension)]
    if not fileList:
        print("No images found with extension: {}".format(fileExtension))
        raise IOError("No images found with given extension.")
    
    # Process each image file individually
    for _, fileName in enumerate(fileList):
        processSingleImage(inputDir, fileName, outputDir, segmentation_file, tracking_file, settings)
        IJ.run("Close All")
    
    if (mode == "calibration"):
        set_mode("analysis")


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


def resize_image(imp, resizeDim, newSize):
    """
    Resizes a single image based on the given settings and returns its original dimensions for reversion.

    Parameters:
        imp (ImagePlus): An ImagePlus object representing the image to be resized.
        resizeDim (str): The dimension to change. Either 'Width' or 'Height'.
        newSize (int): The desired size in pixels for the selected dimension.

    Returns:
        tuple: A tuple containing the original width and height of the image before resizing.
    """
    
    origWidth = imp.width
    origHeight = imp.height

    # Calculate scaling factor and new dimensions
    if resizeDim == "Width":
        scaleFactor = float(newSize) / origWidth
        newWidth = newSize
        newHeight = origHeight * scaleFactor
    else:  # resizeDim == "Height"
        scaleFactor = float(newSize) / origHeight
        newHeight = newSize
        newWidth = origWidth * scaleFactor

    # Resize the image using ImageJ's run command
    IJ.run("Size...", "width=" + str(newWidth) + " height=" + str(newHeight) + " constrain interpolation=Bicubic")

    return (origWidth, origHeight)


def revert_image_size(original_dims):
    """
    Reverts a single image to its original size based on stored dimensions.

    Parameters:
        original_dims (tuple): A tuple containing the original width and height of the image.
    """
    origWidth, origHeight = original_dims

    # Set the width and height directly using the original dimensions
    IJ.run("Size...", "width=" + str(origWidth) + " height=" + str(origHeight) + " constrain interpolation=Bicubic")



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
    
    return None

# Starting the main function
main()
