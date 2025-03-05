/*
	# File: ../setup.ijm
	# Description: Fiji macro setup file designed to assist users in configuring and calibrating essential parameters effectively. 
	# Author: Korenić Andrej, Ph.D, Research Associate
	# Affiliation: Department for General Physiology and Biophysics,
				   Institute for Physiology and Biochemistry "Ivan Djaja",
				   University of Belgrade, Faculty of Biology, Serbia
	# Created on: 2025-02-27
	# Version: 1.0.0
	# License: The Intellectual Property Office of the Republic of Serbia (No. A-0517/2014 9593)
	# Dependencies: [coming soon...]
	# Usage: use the Fiji editor's `Macros > Run Macro` command
	# Revision History: N/A
	# Contact: andrej.korenic@bio.bg.ac.rs
	# Note to the user:	I would recommend careful attention to the details presented in the Log Window, including all instructions that are displayed.

	# Copyright (C) 2025 Korenić Andrej
*/

/*
------------------------------------------------------------------------------------------------------------------------------
	0. BEFORE IT GETS STARTED...
------------------------------------------------------------------------------------------------------------------------------
*/

// Define constants for delimiter and end-of-line
var DELIM = "="; // You have the option to specify a preferred delimiter between variables and their corresponding parameters
var EOL = "\n";   // End-of-line character

/*
Users should only modify parameters from this point forward if they fully understand their functions and are certain of the necessity and potential consequences of such changes.
*/

var sep = File.separator; // gets "\" on Windows and "/" on Unix
var origWidth = 0;
var origHeight = 0;
var contrastSaturation = 0.35;
var resizeMe = false;
var swapDims = false;
var resizeDim = "None";
var newSize = 0;

// closes and clears anything already open
run("Close All");

if (isOpen("Log")) {
	selectWindow("Log");
	run("Close");
}

/*
------------------------------------------------------------------------------------------------------------------------------
	1. PRE CHECKS
------------------------------------------------------------------------------------------------------------------------------
*/

print("\nBefore we start --- maximize the Log window then click OK."); // Prompt user to maximize the Log window
print("\n* * *  This is where you will find all important messages and instructions.  * * *");
waitForUser("Maximize Log window then click OK"); // Pause execution until the user clicks OK

// Check if the Log window is open
if (isOpen("Log")) { // If open, reposition Log window in the top left corner
    selectWindow("Log"); // Bring Log window to the foreground
    setLocation(0, 0); // Position Log window at coordinates (0, 0)
} else {
    showMessage("Error", "Log window is not open or cannot be found."); // Alert user if Log window is not found
    exit();  // Stop the macro execution if Log window is not accessible
}

var rootDir = getDirectory("current"); // Get the directory of the setup.ijm

print("\\Clear"); // Clear any previous content in the Log window
print("\n=== SETUP ==="); // Start of the setup process

wait(500);
print("\nSTEP 1: Will you be using a predefined settings for folder organization?");

if(getBoolean("Using predefined folder settings?")) { 
    // If yes, load folder structure from settings file
	loadSettingsFile("folder_structure");

    // Convert file paths to use correct separator instead of forward slashes
	calibrationInputFolder = replace(List.get("calibrationInputFolder"), "/", sep);
	calibrationOutputFolder = replace(List.get("calibrationOutputFolder"), "/", sep);
	analysisInputFolder = replace(List.get("analysisInputFolder"), "/", sep);
	analysisOutputFolder = replace(List.get("analysisOutputFolder"), "/", sep);

} else {
    // If no predefined settings, let user select folders manually
	happyWithFolders = false;
	while (happyWithFolders == false) {
		// Step 1: Get directories from user

		// Prompt for calibration input folder
		print("              - Please select the folder containing calibration images.");
		calibrationInputFolder = getDirectory("Select Calibration Input Folder");

		// Prompt for calibration output folder
		print("              - Please select the folder where the output from the calibration process will be saved.");
		calibrationOutputFolder = getDirectory("Select Calibration Output Folder");

		// Prompt for analysis input folder
		print("              - Please select the folder containing images for batch analysis");
		analysisInputFolder = getDirectory("Select Analysis Input Folder");

		// Prompt for analysis output folder
		print("              - Please select the folder where the output from the analysis will be saved");
		analysisOutputFolder = getDirectory("Select Analysis Output Folder");

		// Step 2: Display the selected folders to the user for confirmation
		Dialog.create("Recap Folders");
		Dialog.addString("Calibration Input Folder:", calibrationInputFolder, 100);
		Dialog.addString("Calibration Output Folder:", calibrationOutputFolder, 100);
		Dialog.addString("Analysis Input Folder:", analysisInputFolder, 100);
		Dialog.addString("Analysis Output Folder:", analysisOutputFolder, 100);
		Dialog.show();

		// Step 3: Confirm with the user if the folders are correct
		print("              - Are these folders correct? Click 'No' to select different folders.");
		happyWithFolders = getBoolean("Are these folders correct?"); // If 'No', loop will repeat
	}

    // Retrieve confirmed folder paths from dialog input
	calibrationInputFolder = Dialog.getString();
	calibrationOutputFolder = Dialog.getString();
	analysisInputFolder = Dialog.getString();
	analysisOutputFolder = Dialog.getString();

	// Define the parameter names for saving purposes
	parameterNames = newArray(
		"calibrationInputFolder",
		"calibrationOutputFolder",
		"analysisInputFolder",
		"analysisOutputFolder"
	);

	// Create an array of parameter values in the same order as parameterNames
	parameterValues = newArray(
		calibrationInputFolder,
		calibrationOutputFolder,
		analysisInputFolder,
		analysisOutputFolder
	);
	
	saveParameterFile("folder_structure", parameterNames, parameterValues); // Save the folder paths as a file
}

// Will stay in the next while loop choosing parameter values until happyWithValues==true
happyWithValues=false;

wait(500);
print("\nSTEP 2: Do you have an existing settings file with your desired analysis parameters?");

if(getBoolean("Loading predefined analysis settings?")) {
// if user has already decided parameter values in previous runs
	loadSettingsFile("analysis_settings");
	happyWithValues = true;
}

wait(500);
print("\nSTEP 3: Place your images into the designated \"calibration\" and \"analysis\" folders");
print("                as indicated by the folder structure setup in previous steps.");
waitForUser("Click 'OK' to continue.");

openFolder(calibrationInputFolder); // Open the folder containing calibration images

// Check if any images were loaded from the folder
if(nImages == 0) {
	print("\n=== WARNING ===\nNo images in calibration input folder."); // Warn if no images found
	exit(); // Stop execution if no images are present
}

print("              - Converting all calibration images to 8-bit... "); // Inform user of 8-bit conversion process

selectImage(1); // Select the first image
// Extracting the name and extension
currentImgTitle = getTitle();
result = getBaseNameAndExtension(currentImgTitle);

// Extract the values from the array
baseName = result[0];
fileExtension = result[1];

for (i = 0; i < nImages; i++) {
	selectImage(i+1);
	run("8-bit");
}

wait(200);
print("              - Done."); // Confirm completion of conversion

while(happyWithValues==false) {
	wait(200);

	// Ask the user whether to change dimensions
	print("\nSTEP 4: Do you want to change the dimensions of the images?");
	resizeMe = getBoolean("Change images size?");

	if (resizeMe) {
		// Ask user if they want to change dimensions
		Dialog.create("Change Image Dimensions");
		// Ask the user for the dimension to change and the desired size
		Dialog.addChoice("Dimension to change:", newArray("Width", "Height"), "Width");
		Dialog.addNumber("New size (pixels):", 512);
		Dialog.show();
		// Get user inputs
		resizeDim = Dialog.getChoice();
		newSize = Dialog.getNumber();

		for (i = 0; i < nImages; i++) {
			selectImage(i + 1); // select each image by its index (1-based)

			// Store original dimensions
			origWidth = getWidth();
			origHeight = getHeight();

			// Calculate scaling factor and new dimensions
			if (resizeDim == "Width") {
				scaleFactor = newSize / origWidth;
				newWidth = newSize;
				newHeight = origHeight * scaleFactor;
			} else if (resizeDim == "Height") {
				scaleFactor = newSize / origHeight;
				newHeight = newSize;
				newWidth = origWidth * scaleFactor;
			}

			// Resize the selected image to specified width and height
			// "constrain" maintains the aspect ratio, and "interpolation=Bicubic" ensures smooth scaling
			run("Size...", "width=" + newWidth + " height=" + newHeight + " constrain interpolation=Bicubic");
		}
	}

	// Adjust contrast of image
	wait(200);
	print("\nSTEP 5: Automatically adjusting color balance by saturating 35% of the pixel values.");
	wait(200);

	for (i=0;i<nImages;i++) {
	    selectImage(i+1);
	    run("Enhance Contrast", "saturated=0.35");
	}

	// Prompt the user to check image contrast and sharpness in the calibration set
	print("              - Check the contrast and sharpness of calibration images for analysis readiness.");
	waitForUser("Review images, then click 'OK'"); // TODO: reposition
	happyContrast = getBoolean("Is it OK like this?");

	// Loop to adjust contrast until the user is satisfied
	while (happyContrast == false) {
		// Ask the user for a saturation value to enhance contrast, with a suggested default of 0.35
		testSaturationValue = getNumber("Enter a saturation value (between 0 and 1) to adjust contrast", 0.35);
		wait(200);

		// Apply the selected contrast enhancement to each image in the set
		for (i = 0; i < nImages; i++) {
			selectImage(i + 1);
			run("Enhance Contrast", "saturated=" + testSaturationValue);
		}

		contrastSaturation = testSaturationValue; // Store the selected saturation value for reference

		// Prompt user to re-evaluate contrast
		print("              - Please review the contrast adjustments of the calibration images.");
		waitForUser("Review images, then click 'OK'");
		happyContrast = getBoolean("Is this better?");
	}

	wait(500);
	print("\nSTEP 6: FINAL CHECK!");
	wait(400);
	print("                Good! Shall we go ahead and choose the settings for segmentation and tracking?");
	wait(200);

	// Check with the user to next step. If not then programme exits.
	endPrechecks = getBoolean("Ready to continue?");
	if(endPrechecks==false) {
		showMessage("Aborted", "Please relaunch the script to repeat the precheck process.");
		exit();
	}

/*
------------------------------------------------------------------------------------------------------------------------------
	2.CHOOSING SEGMENTATION AND TRACKING PARAMETERS
------------------------------------------------------------------------------------------------------------------------------
*/

	saveAs("Tiff", calibrationOutputFolder + "01_segmentation\\" + baseName);
	run("Close All");

	// Reopen because of the TrackMate
	open(calibrationOutputFolder + "01_segmentation\\" + baseName + ".tif");
	run("Out [-]"); // zoom out

	print("\\Clear"); // Clear the log window
	print("\n=== Getting ready to run TrackMate for segmentation ===");
	print("\nWhen you start TrackMate for the first time, you might see a warning like this:");
	print("\n    \"It appears this image has 1 timepoint but __ slices. Do you want to swap Z and T?\"");
	wait(600);
	print("\nIf this happens, click `Yes` and take note for yourself that TrackMate");
	print("asked you to swap the Z (depth) and T (time) dimensions.");
	wait(300);
	print("\nIt's important to remember this choice for later steps,");
	print("as it may affect how your images are processed.");
	waitForUser("Please check Log window for messages.");
	wait(200);

	wait(500);
	print("\n=== Using TrackMate to the segment image. ==="); wait(400);
	print("              1) Utilize TrackMate to perform image segmentation as needed."); wait(300);
	print("              2) Once you have finished using TrackMate for image segmentation,");
	print("                   ensure you export your settings to an XML file."); wait(300);
	print("              3) Export your labeled image, which will be denoted with a name starting with 'LblImg.");
	print("                   Untick both options and label should be track ID."); wait(300);
	print("              4) Upon completion of your analysis with TrackMate, proceed by");
	print("                   closing the TrackMate window and clicking 'OK' to move forward."); wait(300);
	run("TrackMate");
	wait(3000);
	waitForUser("Click 'OK' to continue.");
	
	// Ask the user whether to change dimensions
	print("\n              - Did TrackMate ask you to swap the Z (depth) and T (time) dimensions?");
	wait(200);
	swapDims = getBoolean("Did you have to swap dimensions?");
	
	// Make two image duplicates
	run("Duplicate...", "title=segmentation-mask-32bit duplicate");

	if (swapDims) {
		selectImage(currentImgTitle);
		saveAs("Tiff", calibrationOutputFolder + "01_segmentation\\" + baseName);
		wait(200);
		selectImage("segmentation-mask-32bit");
	}
	
	run("Duplicate...", "title=segmentation-mask-8bit duplicate");
	
	// Make a binary image to segment the original image
	selectImage("segmentation-mask-8bit");
	run("8-bit");
	run("Max...", "value=1 stack");
	imageCalculator("Multiply stack", currentImgTitle,"segmentation-mask-8bit");
	
	selectWindow(currentImgTitle);
	
	saveAs("Tiff", calibrationOutputFolder + "02_tracking\\" + baseName);
	close(currentImgTitle);
	
	// Reopen because of the TrackMate
	open(calibrationOutputFolder + "02_tracking\\" + baseName + ".tif");
	run("Out [-]"); // zoom out
	
	// Working with TrackMate for the second time for tracking
	print("\n=== Using TrackMate to track and refine segmented image. ==="); wait(400);
	print("              1) Utilize TrackMate to perform tracking as needed."); wait(300);
	print("              2) Once you have finished using TrackMate for tracking,");
	print("                   ensure you export your settings to an XML file."); wait(300);
	print("              3) Export your labeled image, which will be denoted with a name starting with 'LblImg.");
	print("                   Tick both options and label should be track ID."); wait(300);
	print("              4) Upon completion of your analysis with TrackMate, proceed by");
	print("                   closing the TrackMate window and clicking 'OK' to move forward."); wait(300);
	run("TrackMate");
	wait(3000);
	waitForUser("Click 'OK' to continue.");
	
	rename("tracked_original_image");
	
	// // Refine mask
	// if (swapDims) { // If dimensions were swapped, revert the process
	// 	selectImage("segmentation-mask-32bit");
	// 	run("Re-order Hyperstack ...", "channels=[Channels (c)] slices=[Frames (t)] frames=[Slices (z)]");

	// 	selectImage("tracked_original_image");
	// 	run("Re-order Hyperstack ...", "channels=[Channels (c)] slices=[Frames (t)] frames=[Slices (z)]");
	// }
	
	// // Run refineMask script
	// runMacro(rootDir + "refineMask.ijm","segmentation-mask-32bit tracked_original_image");

	// selectImage("combinedMask");

	// Storing TrackMate segmentation and tracking settings file
	segmentationSettingsFile = calibrationOutputFolder + "01_segmentation\\" + baseName + ".xml";
	trackingSettingsFile = calibrationOutputFolder + "02_tracking\\" + baseName + ".xml";

	wait(200);
	
/*
------------------------------------------------------------------------------------------------------------------------------
	3. CONFIRM PARAMETERS
------------------------------------------------------------------------------------------------------------------------------
*/
	print("\\Clear"); // Clear the log window

	Dialog.create("Recap values");

	// User can override any values here

	Dialog.addNumber("Contrast Saturation:", contrastSaturation);
	Dialog.addCheckbox("Swap Dimensions", swapDims);
	Dialog.addCheckbox("Resize Images", resizeMe);

	if (resizeMe) {
		Dialog.addString("Dimension to Resize:", resizeDim, 10);
		Dialog.addNumber("New Size:", newSize);
	}
	Dialog.show();

	contrastSaturation = Dialog.getNumber();
	swapDims = Dialog.getCheckbox();
	resizeMe = Dialog.getCheckbox();

	if (resizeMe) {
		resizeDim = Dialog.getString();
		newSize = Dialog.getNumber();
	};

	// Define parameter names as strings
	parameterNames = newArray(
		"contrastSaturation",
		"swapDims",
		"resizeMe",
		"resizeDim",
		"newSize",
		"segmentationSettingsFile",
		"trackingSettingsFile",
		"fileExtension"
	);

	// Create an array of parameter values in the same order as parameterNames
	parameterValues = newArray(
		contrastSaturation,
		swapDims,
		resizeMe,
		resizeDim,
		newSize,
		segmentationSettingsFile,
		trackingSettingsFile,
		fileExtension
	);

	happyWithValues = getBoolean("Are you happy with the parameter values? Click 'No' to start over");
	if(happyWithValues==false) {
		print("Exiting macro: go back to start of prechecks to choose parameter values again.");
		wait(200);
	}
	else {
		print("\n=== Saving config file for automation. ===");
		// Save these parameters to a .txt file to root directory
		saveParameterFile("analysis_settings", parameterNames, parameterValues);
	}
}

wait(500);

close("*"); //close everything

print("\n\n=== FINISHED EVERYTHING! ===\n\n");

parameterNames = newArray("mode");

print("\nWould you like to analize the rest of the images from the calibaration folder?");
setMode = getBoolean("Continue calibaration?");

if (setMode) {
	parameterValues = newArray("calibration");
} else {
	parameterValues = newArray("analysis");
}

saveParameterFile("mode", parameterNames, parameterValues);



/*
*------------------------------------------------------------------------------------------------------------------------------
*	5. FUNCTIONS
*------------------------------------------------------------------------------------------------------------------------------
*
* The section contains a set of functions designed to manage and process image files, 
* as well as to save and load settings. 
*/


/**
 * The function takes the file path and filename as input, constructs the full path,
 * and checks if the file exists. If the file is found, it opens the image and applies
 * a zoom out operation to fit the entire image on the screen.
 *
 * @param {string} path   The directory path where the image file is located.
 * @param {string} fileName   The name of the image file to be opened.
 */
// Function to open a file and perform operations
function openFile(path, fileName) {
	path = replace(path, "/", sep);
    print("              - Opening file: " + path + File.separator + fileName);
    if (File.exists(path + File.separator + fileName)) {
		open(path + File.separator + fileName);
        run("Out [-]"); // zoom out
    } else {
        print("                 === Error: Failed to open file ===\n");
        return;
    }
}


/**
 * Opens a specified folder and processes all files within it. The function checks if the provided path
 * corresponds to an existing directory, and if so, retrieves all file entries within that directory,
 * sorts them, and opens each file individually. If the input is not a valid directory or does not exist,
 * an error message is printed.
 *
 * @param {string} path The directory path that needs to be opened and processed.
 */
// Function to open a folder which can contain either files or directories and perform appropriate actions
function openFolder(path) {
	path = replace(path, "/", sep);
    // Check if the input is a directory first
    if (!File.isDirectory(path)) {
		print("\n              - Tried to open: " + path);
        print("                 === Error: The provided input is not a directory or it does not exist ===\n");
    } else {
		print("\n              - All files in directory will be processed.");
		// If it's a directory, proceed to get all files within it and open them
		fileEntries = getFileList(path); // Get all entries in the input folder
		fileEntries = Array.sort(fileEntries);
		for (i = 0; i < fileEntries.length; i++) {
			if (!File.isDirectory(path + File.separator + fileEntries[i])) {
				openFile(path, fileEntries[i]); // Open each file within the directory
			}
		}
	}
}


/**
 * Saves parameters to a text file with specified names and values.
 *
 * @param {string} fileName - The base name of the file to be saved (without extension).
 * @param {Array<string>} parameterNames - An array containing the names of the parameters.
 * @param {Array<any>} parameterValues - An array containing the corresponding values of the parameters.
 */
function saveParameterFile(fileName, parameterNames, parameterValues) {
    // Ensure that the number of parameter names matches the number of parameter values
    if (parameterNames.length != parameterValues.length) {
        print("\n=== Error: The number of parameter names and values must be the same. ===");
        return;
    }

    // Construct the full file path by combining the directory, file name, and extension
    parameterFilePath = rootDir + "setup_settings/" + fileName + ".txt";
    // Use forward slashes for saving
    parameterFilePath = replace(parameterFilePath, "/", "\\");
    print("              - Saving parameter file to: " + parameterFilePath);

    // Check if a file with the same name already exists
    if (File.exists(parameterFilePath)) {
        // Attempt to delete the existing file before creating a new one
        if (!File.delete(parameterFilePath)) {
            print("\n=== Error: Unable to delete existing parameter file. ===");
            exit(); // Terminate the script if deletion fails
        }
    }

    // Open the file for writing; this creates a new file if it doesn't exist
    parameterFile = File.open(parameterFilePath);

    // Verify that the file was successfully opened (and thus created)
    if (!File.exists(parameterFilePath)) {
        print("\n=== Error: Unable to create parameter file. ===");
        return;
    }

    // Iterate through each parameter name and value pair
    for (i = 0; i < parameterNames.length; i++) {
        // Construct a line with the format: parameterName<DELIM>parameterValue<EOL>
        line = parameterNames[i] + DELIM + parameterValues[i] + EOL;
        // Write the constructed line to the parameter file
        print(parameterFile, line);
    }

    // Close the file to ensure all data is properly saved and resources are released
    File.close(parameterFile);
    print("              - Parameter file saved successfully.");
}


/**
 * Loads parameters from a text file with specified names and values.
 *
 * @param {string} fileName - The base name of the file to be saved (without extension).
 */
function loadSettingsFile(fileName){

    // Construct the full file path by combining the directory, file name, and extension
    parameterFile = rootDir + "setup_settings/" + fileName + ".txt";
    // Use forward slashes for saving
    parameterFile = replace(parameterFile, sep, "/");
    print("              - Loading parameter file from: " + parameterFile);

	// Open the file and read its content as a string
	content = File.openAsString(parameterFile);

	// Split the file content into an array of lines based on the end-of-line character
	lines = split(content, EOL);

	// Get the number of lines in the file
	nLines = lengthOf(lines);

	// Clear any existing entries in the List to prepare for new key-value pairs
	List.clear();

	// Loop through each line to parse key-value pairs
	for (i = 0; i < lengthOf(lines); i++) {
		line = lines[i];

		// Skip empty lines or lines that start with a comment character ('#')
		if (line == "" || startsWith(line, "#")) {
			continue;  // Move to the next iteration if the line is empty or a comment
		}

		// Split the line by the DELIM to separate the key and value
		keyValue = split(line, DELIM);

		// Ensure the line contains exactly one '=' to be a valid key-value pair
		if (lengthOf(keyValue) == 2) {
			key = trim(keyValue[0]);    // Get the key, trimming any leading/trailing whitespace
			value = trim(keyValue[1]);  // Get the value, trimming any leading/trailing whitespace

			// Store the key-value pair in the List
			List.set(key, value);
		}
	}
}


/**
 * Extracts the base name and file extension from a given image title. This function searches for the last
 * occurrence of a dot '.' in the title to separate the base name from the file extension.
 *
 * @param {string} title The image title containing the base name and potentially a file extension.
 * @return {Array<string>} An array containing two elements: the base name (at index 0) and the file extension (at index 1).
 */
// Function to remove the file extension from a given image title
function getBaseNameAndExtension(title) {
    // Find the position of the last dot '.' in the title
    dotIndex = lastIndexOf(title, ".");

    // Check if a dot was found in the title
    if (dotIndex != -1) {
        // Extract the substring from the start up to (but not including) the last dot
        baseName = substring(title, 0, dotIndex);
		fileExtension = substring(title, dotIndex + 1, lengthOf(title));
    } else {
        exit("Error: File title has no extension...");
    }

	// Return both values as an array
    return newArray(baseName, fileExtension);
}


// // ----- Unit Test Functions -----
// // Uncomment the tests you wish to run

// // Test 1: Opening an existing file
// openFile("C:/Users/Andrej/Desktop/segmentation_script", "LblImg_test_image_1.tif");
// // Expected Output: - Opening file: path\to\file\test.tif

// // Test 2: Trying to open a non-existing file
// openFile("C:/Users/Andrej/Desktop/segmentation_script", "sample_image_2.png");
// // Expected Output: === Error: Failed to open file ===

// // Test 3: Opening an existing directory
// openFolder("C:/Users/Andrej/Desktop/segmentation_script/calibrationInput");
// // Expected Output: All files in directory will be processed.

// // Test 4: Trying to open a non-existing directory
// openFolder("C:/Users/Andrej/Desktop/segmentation_script/calibrationInput/temp");
// // Expected Output: === Error: The provided input is not a directory or it does not exist ===

// // Test 5: Trying to open a non-existing directory
// openFolder("C:/Users/Andrej/Desktop/segmentation_script/LblImg_test_image_1.tif");
// // Expected Output: === Error: The provided input is not a directory or it does not exist ===