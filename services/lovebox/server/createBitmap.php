<?php
  $brightness = $_POST["brightness"];

	$imageBlob = base64_decode($_POST["imageBlob"]);

	$originalImage = new Imagick();
	$originalImage->readImageBlob($imageBlob);

	$width = $originalImage->getImageWidth();
	$height = $originalImage->getImageHeight();

	$newImage = new Imagick();
	$newImage->newImage($width, $height, new ImagickPixel('white'), 'jpg');

	$bitMap = "";

	$quantError = array_fill(0, $width, array_fill(0, $height, 0));

	$iterator = $newImage->getPixelIterator();
	foreach ($iterator as $row=>$pixels) {
		foreach ($pixels as $col=>$pixel) {

			$originalPixel = $originalImage->getImagePixelColor($col, $row);

			$originalRed = $originalPixel->getColorValue(Imagick::COLOR_RED);
			$originalGreen = $originalPixel->getColorValue(Imagick::COLOR_GREEN);
			$originalBlue = $originalPixel->getColorValue(Imagick::COLOR_BLUE);

			$originalColor = ($originalRed + $originalGreen + $originalBlue) / 3 + $quantError[$col][$row] + $brightness;

			if($originalColor > 0.5) {
				$bitMap = $bitMap . "1";
				$error = $originalColor - 1;
			} else {
				$bitMap = $bitMap . "0";
				$pixel->setColor('rgba(0%, 0%, 0%, 1.0)');
				$error = $originalColor - 0;
			}

			if($col < ($width - 1)) {
				$quantError[$col+1][$row] += $error * 7/16;
			}

			if($row < ($height - 1)) {
				if($col > 0) {
					$quantError[$col-1][$row+1] += $error * 3/16;
				}
				$quantError[$col][$row+1] += $error * 5/16;
				if($col < ($width - 1)) {
					$quantError[$col][$row+1] += $error * 1/16;
				}
			}
		}
		$iterator->syncIterator();
	}
    $blob = $newImage->getImageBlob();

	$response = array("imgBlob"=>base64_encode($blob), "bitMap"=>$bitMap);
	header('Content-type: application/json');
	echo json_encode($response);
?>
