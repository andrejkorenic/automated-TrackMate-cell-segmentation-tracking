/*
	# File: ../auxiliary_scripts.ijm
	# Description: This file consolidates a collection of auxiliary scripts 
    #              designed to streamline various tasks within a macro environment.
	# Author: Korenić Andrej, Ph.D, Research Associate
	# Affiliation: Department for General Physiology and Biophysics,
				   Institute for Physiology and Biochemistry "Ivan Djaja",
				   University of Belgrade, Faculty of Biology, Serbia
	# Created on: 2025-04-17
	# Version: 1.0.0
	# License: GPL-3.0 & The Intellectual Property Office of the Republic of Serbia (No. A-0517/2014 9593)
	# Dependencies: ImageJ/Fiji 1.54p, Java 1.8.0_322 (64-bit), TrackMate 7.14.0

	# Copyright (C) 2025 Korenić Andrej
    # https://github.com/andrejkorenic/automated-TrackMate-cell-segmentation-tracking
*/

argstr = getArgument();


if (lengthOf(argstr)==0)
    exit("Error: no arguments were given for 'auxiliary_scripts'.");

args = split(argstr, " ");


if (args[0] == "refineMask") {
    setBatchMode(true);
    refineMask(args[1], args[2]);
    setBatchMode(false);
} else if (args[0] == "fixStack") {
    fixStack(args[1], args[2]);
} else {
    exit("Error: Invalid function call in 'auxiliary_scripts'.");
}


/**
 * Combines and refines two binary 32-bit image masks to create an enhanced mask.
 * 
 * This function performs Voronoi separation on these masks, processes each slice of the image individually, 
 * and returns the refined masks.
 *
 * @param {ImageData} mask1 - The first input mask to be refined. Must be a 32-bit image with compatible dimensions.
 * @param {ImageData} mask2 - The second input mask to be refined. Must be a 32-bit image and have the same dimensions as `mask1`.
 * @returns {void} This function does not return any value but modifies the masks in place.
 */
function refineMask(mask1, mask2) {

    // Verify that both images are 32-bit and have identical dimensions.
    checkImages(mask1, mask2);

    getDimensions(width1, height1, channels1, slices1, frames1);

    // Perform separation with Voronoi diagram.
    performVoronoi(mask1, mask2);
    
    // Process each slice individually.
    for (z = 1; z <= slices1; z++) {
        processImageSlice(mask1, mask2, z);
    }
}


/**
 * Adjusts the stack dimensions of an image based on the specified mode ("in" or "out").
 * 
 * It will create a fake second frame to enable image tracking with TrackMate. 
 * 
 * @param {string} mode - The mode indicating whether to fix the input (in) or output (out) of the stack.
 * @param {ImageData} img - The image whose stack dimensions are to be adjusted.
 * @returns {void} This function does not return any value but modifies the image in place according to the specified mode.
 */
function fixStack(mode, img) {
    requires("1.39l");
    
    selectWindow(img);

    if (mode == "in") {
        getDimensions(w, h, channels, slices, frames);
        if (slices == 1 && frames == 1) {
            run("Duplicate...", "title=fake_frame");
            run("Images to Stack", "name=original_img");
            run("Stack to Hyperstack...", "order=xyczt(default) channels=1 slices=1 frames=2 display=Grayscale");
        } else if (slices > 1 && frames == 1) {
            run("Re-order Hyperstack ...", "channels=[Channels (c)] slices=[Frames (t)] frames=[Slices (z)]");
        }
    } else if (mode == "out") {
        getDimensions(w, h, channels, slices, frames);
        if (slices == 1 && frames == 2) {
            run("Next Slice [>]");
            run("Delete Slice");
        } else if (slices == 1 && frames > 1) {
            run("Re-order Hyperstack ...", "channels=[Channels (c)] slices=[Frames (t)] frames=[Slices (z)]");
        }
    } else {
        exit("Error: invalid mode in 'auxiliary_scripts -> fixStack'.");
    }
}


/**
 * Verifies that two images are 32-bit and have identical dimensions.
 * Additionally, it creates a new image with the same dimensions for further processing.
 *
 * @param {ImageData} image1 - The first image to check.
 * @param {ImageData} image2 - The second image to check.
 * @returns {void} This function does not return any value but prints warnings and exits if the images do not meet the criteria.
*/
function checkImages(image1, image2) {
    // Verify image1.
    selectWindow(image1);
    bitDepth1 = bitDepth;
    if (bitDepth1 != 32) {
        print("\n=== WARNING ===\nImage " + image1 + " must be 32-bit.");
        exit();
    }
    getDimensions(width1, height1, channels1, slices1, frames1);

    // Verify image2.
    selectWindow(image2);
    bitDepth2 = bitDepth;
    if (bitDepth2 != 32) {
        print("\n=== WARNING ===\nImage " + image2 + " must be 32-bit.");
        exit();
    }
    getDimensions(width2, height2, channels2, slices2, frames2);
    
    // Ensure both images have identical dimensions.
    if (width1 != width2 || height1 != height2 || slices1 != slices2 || frames1 != frames2) {
        print("\n=== WARNING ===\nImages must have the same dimensions.");
        exit();
    }

    // --- Create new image with same dimensions ---
    newImage("combinedMask", "32-bit black", width1, height1, slices1);
}


/**
 * Generates a Voronoi diagram to refine masks by processing markers from another mask (`mask2`) and combining them with `mask1`. 
 * This involves duplicating `mask2`, processing it for markers, generating a Voronoi diagram, applying thresholding, 
 * inverting the result, and finally multiplying it with `mask1` to produce a refined binary mask.
 *
 * @param {ImageData} mask1 - The base mask which will be combined with the Voronoi diagram.
 * @param {ImageData} mask2 - The mask from which markers are taken for processing.
 * @returns {void} This function does not return any value but modifies `mask1` in place by combining it with the processed Voronoi diagram.
 */
function performVoronoi(mask1, mask2) {
    
    // --- Process Markers from Mask 2 ---
    selectWindow(mask2);
    
    // Duplicate mask2 for marker processing.
    run("Duplicate...", "title=markers duplicate");
    setAutoThresholdAndConvertToMask();
    
    // --- Generate Voronoi Diagram ---
    run("Duplicate...", "title=voronoi-diagram duplicate");
    run("Voronoi", "stack");
    setAutoThreshold("Default dark");
    setThreshold(0.1, 255, "raw");
    run("Convert to Mask", "background=Dark black");

    // --- Combine Processed Data & Create Binary Mask ---
    run("Invert", "stack");
    imageCalculator("Multiply stack", mask1, "voronoi-diagram");
}


/**
 * Processes a given slice of `mask1` and `mask2`, thresholds pixels in `mask2` according to their intensity, 
 * creates ROIs for these thresholded areas, selects corresponding regions in `mask1`, and modifies them in `combinedMask`.
 *
 * @param {ImageData} mask1 - The first `mask1` that will be modified.
 * @param {ImageData} mask2 - The second `mask2` from which pixel values are used to create ROIs and modify `mask1`.
 * @returns {void} This function does not return any value but modifies `mask1` in place by combining it with the processed Voronoi diagram.
 */
function processImageSlice(mask1, mask2, z) {
    
    // Set the current slice for both masks.
    selectWindow(mask1);
    setSlice(z);
    selectWindow(mask2);
    setSlice(z);
    selectWindow("combinedMask");
    setSlice(z);
    
    // Process image2 for thresholding.
    selectWindow(mask2);
    getRawStatistics(nPixels, mean, min, max);

    createUniquePixelsArray();
    List.toArrays(keys, values);

    numPixels = keys.length;

    // Process each threshold value using ROI operations.
    for (i = 0; i < numPixels; i++) {
        pixelValue = parseInt(values[i]);

        if (pixelValue > 0) {
            selectWindow(mask2);
            setThreshold(pixelValue, pixelValue);
            run("Create Selection");
            roiManager("Add");
            Roi.getContainedPoints(xpoints, ypoints);
            run("Select None");
            run("Clear Results");
            roiManager("Delete");
            resetThreshold();

            selectWindow(mask1);
            doWand(xpoints[0], ypoints[0]);
            roiManager("Add");

            selectWindow("combinedMask");
            roiManager("Select", 0);
            
            // Change pixels in the selection that have a value in the range arg1-arg2 to arg3.
            changeValues(0, 0, pixelValue);
            
            run("Select None");
            run("Clear Results");
            roiManager("Delete");
        }
    }
}


/**
 * Creates an array of unique pixel values from the current image.
 * 
 * @returns {void} This function does not return anything but modifies the state of the List utility to include unique pixel values.
 */
function createUniquePixelsArray() {
    // Ensure List functions are available
    requires("1.41f");
    
    // Clear any previous dictionary info stored in the List
    List.clear();
    
    // Get image dimensions
    width = getWidth();
    height = getHeight();
    
    // Loop over every pixel in the image
    for (y = 0; y < height; y++) {
        for (x = 0; x < width; x++) {
            // Get pixel value at (x,y)
            value = getPixel(x, y);
            // Convert pixel value to a string key for consistent dictionary usage
            key = "" + value;
            
            // Retrieve current count for the key
            count = List.get(key);
            if (count == "") {
                // If the key is not present, initialize with a count of 1
                List.set(key, value);
            }
        }
    }
}


function setAutoThresholdAndConvertToMask() {
  setAutoThreshold("Default dark");
  setThreshold(0.1000, 1.000E30);
  setOption("BlackBackground", true);
  run("Convert to Mask", "background=Dark black");
}