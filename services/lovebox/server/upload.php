<?php
$target_dir = "/messages/media/pictures/";
$target_file = $target_dir . basename($_FILES["fileToUpload"]["name"]);

$imageFileType = strtolower(pathinfo($target_file, PATHINFO_EXTENSION));

// Check if image file is a actual image or fake image
if (isset($_POST["submit"])) {
  if (getimagesize($_FILES["fileToUpload"]["tmp_name"] !== false)) {
    throw new Exeption("Sorry, there was an error uploading your file.");
  }
}

// Check if file already exists
if (file_exists($target_file)) {
  // throw new Exception("Sorry, file already exists.");
  unlink($target_file);
}

// Check file size
if ($_FILES["fileToUpload"]["size"] > 128000000) {
  throw new Exception("Sorry, your file is too large.");
}

// Allow certain file formats
if ($imageFileType != "jpg" && $imageFileType != "png" && $imageFileType != "jpeg" && $imageFileType != "gif") {
  throw new Exception("Sorry, only JPG, JPEG, PNG & GIF files are allowed.");
}

// if everything is ok, try to upload file
if (!move_uploaded_file($_FILES["fileToUpload"]["tmp_name"], $target_file)) {
  throw new Exeption("Sorry, there was an error uploading your file.");
}

// laod the target file as an imagick object
$image = new Imagick($target_file);

$width = $image->getImageWidth();
$height = $image->getImageHeight();


// Preprocess images
if ($imageFileType == "jpg" || $imageFileType == "png" || $imageFileType == "jpeg") {

  // rotate th image to the correct orientation
  $orientation = $image->getImageOrientation();

  switch ($orientation) {
    case imagick::ORIENTATION_BOTTOMRIGHT:
      $image->rotateimage("#000", 180); // rotate 180 degrees
      break;

    case imagick::ORIENTATION_RIGHTTOP:
      $image->rotateimage("#000", 90); // rotate 90 degrees CW
      break;

    case imagick::ORIENTATION_LEFTBOTTOM:
      $image->rotateimage("#000", -90); // rotate 90 degrees CCW
      break;
  }

  // Now that it's auto-rotated, make sure the EXIF data is correct in case the EXIF gets saved with the image!
  $image->setImageOrientation(imagick::ORIENTATION_TOPLEFT);


  if ($width >= 2 * $height) {
    $image->resizeImage(0, 128, imagick::FILTER_GAUSSIAN, 1);
  } else {
    $image->resizeImage(256, 0, imagick::FILTER_GAUSSIAN, 1);
  }

  $newSize = array("width" => $image->getImageWidth(), "height" => $image->getImageHeight());

  // Convert the image to grayscale
  $image->setImageColorspace(imagick::COLORSPACE_GRAY);

  $response = array("imgBlob" => base64_encode($image->getImageBlob()), "size" => $newSize);
  // And gifs
} else {
}

// Delete the original file from the webserver
if (!unlink($target_file)) {
  echo false;
} else {
  header('Content-type: application/json');
  echo json_encode($response);
}
