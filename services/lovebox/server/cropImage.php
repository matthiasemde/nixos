<?php
$imageBlob = base64_decode($_POST["imageBlob"]);
$x = $_POST["x"];
$y = $_POST["y"];

$height = $_POST["height"]; 

$image = new Imagick();
$image->readImageBlob($imageBlob);

$image->cropImage(2 * $height, $height, $x, $y);

$image->resizeImage(0, 64, imagick::FILTER_GAUSSIAN, 1);

$response = array("imgBlob" => base64_encode($image->getImageBlob()));

header('Content-type: application/json');
echo json_encode($response);
?>