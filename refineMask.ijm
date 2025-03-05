/*
	# File: ../setup.ijm
	# Description: Fiji macro setup file designed to assist users in configuring and calibrating essential parameters effectively. 
	# Author: Korenić Andrej, Ph.D, Research Associate
	# Affiliation: Department for General Physiology and Biophysics,
				   Institute for Physiology and Biochemistry "Ivan Djaja",
				   University of Belgrade, Faculty of Biology, Serbia
	# Created on: 2025-02-12
	# Version: 1.0.0
	# License: The Intellectual Property Office of the Republic of Serbia (No. A-0517/2014 9593)
	# Dependencies: [coming soon...]
	# Usage: use the Fiji editor's `Macros > Run Macro` command (or press Ctrl-R)
	# Revision History: N/A
	# Contact: andrej.korenic@bio.bg.ac.rs
	# Note:	- It is advisable to review the documentation and complete the tutorial initially to gain a better understanding of its functionality.
			- debug("break"); // calls the macro debugger when running via `Plugins > Macros > Interactive Interpreter`

	# Copyright (C) 2025 Korenić Andrej
*/

requires("1.34m");
Color.setForeground("#000000");
arg = getArgument();

if (lengthOf(arg)==0)
    exit("error message");

images = split(arg, " ");

refineMask(images[0], images[1]);


/**
 * Combines and refines two binary 32-bit image masks to create an enhanced mask.
 *
 * This function verifies that the input masks are 32-bit and share the same dimensions,
 * then processes them using thresholding, ROI operations, and watershed segmentation
 * to produce a refined combined mask.
 *
 * @param {ImageMask} mask1 - The primary 32-bit image mask.
 * @param {ImageMask} mask2 - The secondary 32-bit image mask.
 * @returns {ImageMask} The refined combined image mask.
 * @throws {TypeError} If either mask is not a valid 32-bit ImageMask.
 * @throws {ProcessingError} If the masks have mismatched dimensions.
 */
function refineMask(mask1, mask2) {
    setBatchMode(true);

    // Verify that both images are 32-bit and have identical dimensions.
    checkImages(mask1, mask2);
	getDimensions(width1, height1, channels1, slices1, frames1);

    // Process each slice individually.
    for (z = 1; z <= slices1; z++) {
        processImageSlice(mask1, mask2, z);
    }

    // Perform the final processing steps.
    finalProcessingSteps(mask1, mask2, slices1);

    setBatchMode(false);
}


/**
 * Checks if both images are 32-bit and have the same dimensions.
 *
 * @param {ImageMask} image1 - The first image mask.
 * @param {ImageMask} image2 - The second image mask.
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
}


/**
 * Processes a single slice of the two image masks.
 *
 * @param {ImageMask} image1 - The first image mask.
 * @param {ImageMask} image2 - The second image mask.
 * @param {number} z - The slice number to process.
 */
function processImageSlice(image1, image2, z) {
    // Set the current slice for both masks.
    selectWindow(image1);
    setSlice(z);
    selectWindow(image2);
    setSlice(z);

    // Process image1 for thresholding.
    selectWindow(image1);
    getRawStatistics(nPixels, mean, min, max);

    // Determine the number of histogram bins (handle special case when max==1).
    if (max == 1) {
        nBins = 1;
    } else {
        nBins = max - 1;
    }
    getHistogram(values, counts, nBins, min, max + 1);

    // Count nonzero histogram bins (ignoring the background).
    nonZeroCount = 0;
    for (i = 1; i < nBins; i++) {
        if (counts[i] > 0) {
            nonZeroCount++;
        }
    }

    if (nonZeroCount > 0) {
        // Build an array of threshold values from nonzero bins.
        result = newArray(nonZeroCount);
        j = 0;
        for (i = 1; i < nBins; i++) {
            if (counts[i] > 0) {
                result[j] = Math.ceil(values[i]);
                j++;
            }
        }

        // Process each threshold value using ROI operations.
        for (k = 0; k < nonZeroCount; k++) {
            selectWindow(image1);
            setThreshold(result[k], result[k]);
            run("Create Selection");
            roiManager("Add");
            run("Select None");
            resetThreshold();

            selectWindow(image2);
            roiManager("Select", 0);
            roiManager("measure");
            // If the ROI is absent in image2, remove it from image1.
            if (getResult("Max") == 0) {
                selectWindow(image1);
                roiManager("Select", 0);
                roiManager("fill");
                run("Select None");
                run("Clear Results");
            }
            roiManager("reset");
            run("Clear Results");
        }
    }
}


/**
 * Performs the final processing steps after per-slice operations.
 *
 * This includes duplicating masks, converting to binary masks, processing edges and markers,
 * generating a Voronoi diagram, and applying marker-controlled watershed segmentation to build the final mask.
 *
 * @param {ImageMask} mask1 - The primary image mask.
 * @param {ImageMask} mask2 - The secondary image mask.
 */
function finalProcessingSteps(mask1, mask2, slices1) {
    // Clear selections and results in mask2.
    selectWindow(mask2);
    run("Select None");
    run("Clear Results");

    // Duplicate mask1 and convert it to a binary mask.
    selectWindow(mask1);
    run("Duplicate...", "title=mask duplicate");
    setAutoThreshold("Default dark");
    setThreshold(0.1000, 1.000E30);
    setOption("BlackBackground", true);
    run("Convert to Mask", "background=Dark black");

    // Duplicate mask1 to extract and process edges.
    selectWindow(mask1);
    run("Duplicate...", "title=edges duplicate");
    run("Find Edges", "stack");
    setAutoThreshold("Default dark");
    setThreshold(0.1000, 1.000E30);
    setOption("BlackBackground", true);
    run("Convert to Mask", "background=Dark black");

    // Process markers from mask2.
    selectWindow(mask2);
    run("Duplicate...", "title=markers duplicate");
    run("Duplicate...", "title=outline-markers duplicate");
    setAutoThreshold("Default dark");
    setThreshold(0.1000, 1.000E30);
    setOption("BlackBackground", true);
    run("Convert to Mask", "background=Dark black");
    run("Dilate", "stack");
    run("Outline", "stack");

    // Generate a Voronoi diagram from the outline markers.
    selectWindow("outline-markers");
    run("Duplicate...", "title=voronoi-diagram duplicate");
    run("Voronoi", "stack");
    setAutoThreshold("Default dark");
    setThreshold(0.1, 255, "raw");
    run("Convert to Mask", "background=Dark black");

    // Prepare a binary version of the mask.
    selectWindow("mask");
    run("Duplicate...", "title=mask-binary duplicate");
    run("Divide...", "value=255 stack");
    imageCalculator("Multiply stack", "voronoi-diagram", "mask-binary");

    // Combine the processed edges and Voronoi diagram.
    imageCalculator("Add stack", "edges", "voronoi-diagram");

    // Create a new image to store the final combined mask.
    newImage("combinedMask", "32-bit black", width1, height1, slices1);

    // Apply marker-controlled watershed segmentation on each slice.
    for (z = 1; z <= slices1; z++) {
        selectImage("edges");
        setSlice(z);
        run("Duplicate...", "title=edges-slice");

        selectImage("markers");
        setSlice(z);
        run("Duplicate...", "title=markers-slice");

        selectImage("mask");
        setSlice(z);
        run("Duplicate...", "title=mask-slice");

        run("Marker-controlled Watershed", "input=edges-slice marker=markers-slice mask=mask-slice compactness=0 calculate use");

        selectWindow("combinedMask");
        setSlice(z);
        imageCalculator("Copy", "combinedMask", "edges-slice-watershed");
        close("*slice*");
    }
}