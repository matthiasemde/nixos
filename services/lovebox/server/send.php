<?php
$datapath = "messages";

if ($_POST["txt_input"] != "" || $_POST["img_input"] != "") {
  // open note with read permission and read the current counter value
  $note = fopen("{$datapath}/note", "r") or die("Unable to open file!");
  $id = (int)fgets($note) + 1;
  fclose($note);

  // open note with write permission and write the increased counter value to it
  $note = fopen("{$datapath}/note", "w") or die("Unable to open file!");
  fwrite($note, sprintf("%d\n", $id));

  // depending on the message type, write the text or image into the note
  switch ($_POST["msgType"]) {
    case "t":
      $msg = str_replace("\x0D\x0A", "\x0A", $_POST["txt_input"]); // replace CRLF with LF
      fwrite($note, "t\n" . $msg);
      break;
    case "b":
      fwrite($note, "b\n" . $_POST["img_input"]);
      $msg = $id . ".jpg";
      break;
    default:
  }
  fclose($note);

  // save and format the time when the message was send
  $time_send = time();
  $time_formatted = date("d/m/y H:i", $time_send);

  $historyFile = fopen("{$datapath}/history", "a") or die("Unable to open file!");

  fwrite($historyFile, "__next_msg__\x0A");
  fwrite($historyFile, $msg);
  fwrite($historyFile, "\x0A__meta_data__\x0A");
  fwrite($historyFile, time() . "\x0A"); // send time
  fwrite($historyFile, "false" . "\x0A"); // read status
  fwrite($historyFile, $_POST["msgType"] . "\x0A"); // file type

  fclose($historyFile);

  // if the msg is an image, the value of $msg needs to be changed to the actual image rather then the path before returning
  if ($_POST["msgType"] == "b") {
    $imgBlob = $_POST["imageBlob"];

    $img = new Imagick();
    $img->readImageBlob(base64_decode($imgBlob));
    $img->setImageFormat("jpeg");
    $img->writeImage("{$datapath}/media/pictures/{$id}.jpg");

    $msg = '<img src="data:image/jpg;base64,' . $imgBlob . '" alt="" />';
  }
  echo <<<EOT
        $msg
        <span class="metadata">
            <span class="time">
                $time_formatted
            </span>
            <span class="read">
            </span>
        </span>
EOT;
}
