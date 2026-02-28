<?php
function console_log($data)
{
  echo "<script> console.log(json_encode({$data})) </script>";
}

$datapath = "messages";
?>

<html>

<head>
  <link rel="stylesheet" href="https://fonts.googleapis.com/css?family=Gayathri">
  <link rel="stylesheet" href="https://fonts.googleapis.com/icon?family=Material+Icons">
  <script src="https://ajax.googleapis.com/ajax/libs/jquery/3.4.1/jquery.min.js"></script>
  <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
</head>

<body>
  <div class="page">
    <!-- The overlay -->
    <div id="imgCrop" class="overlay" style="display: none;">

      <div class="overlay-content">
        <img id="cropImg" src="" alt="Bitte ein Bild auswählen">
        <div id="cropWindow">
          <span id="topLeft" class="cropWindowCorner"></span>
          <span id="topRight" class="cropWindowCorner"></span>
          <span id="bottomLeft" class="cropWindowCorner"></span>
          <span id="bottomRight" class="cropWindowCorner"></span>
        </div>
      </div>

      <!-- Buttons to close the overlay navigation or accept the image-->
      <div class="buttonBar">
        <button type="button" onclick="closeOverlay()">
          <i class="material-icons">clear</i>
        </button>
        <button type="button" onclick="confirmCrop()">
          <i class="material-icons">done</i>
        </button>
      </div>

    </div>
    <div class="status_bar">
      <span>Lovebox</span>
      <span class="status">online</span>
    </div>
    <div class="chat_window">
      <div class="messages">
        <?php
        date_default_timezone_set('CET');
        $history = file_get_contents("{$datapath}/history");
        if ($history != "")
          $history_msgs = explode("\x0A__next_msg__\x0A", $history);
        else
          $history_msgs = [];

        $order = 0;

        foreach ($history_msgs as $history_msg) {
          $history_msg = explode("\x0A__meta_data__\x0A", $history_msg);
          $metadata = explode("\x0A", $history_msg[1]);
          $time_formatted = date("d/m/y H:i", $metadata[0]);
          echo "				<div class=\"message\" style=\"order: {$order};\">\n";
          switch ($metadata[2] ?? "t") {
            case "t":
              echo $history_msg[0];
              break;
            case "b":
              $img = new Imagick("{$datapath}/media/pictures/{$history_msg[0]}");
              echo '<img src="data:image/jpg;base64,' . base64_encode($img->getImageBlob()) . '" alt="" />';
              break;
            default:
              echo $history_msg[0];
          }
          echo <<<EOT

					<span class="metadata">
						<span class="time">
							$time_formatted
						</span>
						<span class="read">
						</span>
					</span>
				</div>

EOT;
          $order--;
        }
        ?>
      </div>

      <script>
        let order = <?php echo $order; ?>
      </script>

      <form class="chat_form" action="index.php" method="post">
        <input type="text" id="msgType" name="msgType" value="t" style="display: none;">
        <div id="emoji">
          <button type="button" onclick="openOverlay()">
            <i class="material-icons">mood</i>
          </button>
        </div>
        <div id="text">
          <TEXTAREA
            name="txt_input"
            rows="1"
            cols="20"
            maxlength="80"
            wrap="hard"
            placeholder="Type a message"></TEXTAREA>
        </div>
        <div id="cancel" style="display: none;">
          <button type="button">
            <i class="material-icons">clear</i>
          </button>
        </div>
        <div id="brightness" style="display: none;">
          <input id="brightnessInput" name="brightness" type="number" min="-10" max="10" step="1" value="0" style="display: none;">
          <div>
            <button type="button" onclick="increaseBrightness()" class="arrow">
              <i class="material-icons" id="incBrightButton">keyboard_arrow_up</i>
            </button>
            <label for="brightness">
              <i class="material-icons" id="brightnessIcon">brightness_4</i>
            </label>
            <button type="button" onclick="decreaseBrightness()" class="arrow">
              <i class="material-icons" id="decBrightButton">keyboard_arrow_down</i>
            </button>
          </div>
        </div>
        <div id="imgPreview" style="display: none;">
          <img id="realImgPreview" src="" alt="Bitte ein Bild auswählen">
        </div>
        <input type="text" id="bitMap" name="img_input" style="display: none;">
        <div class="image">
          <button type="button" onclick="openFileSelector()">
            <i class="material-icons">local_see</i>
          </button>
          <input type="file" name="fileSelector" style="display: none" id="fileSelector">
        </div>
        <div class="send">
          <button type="submit">
            <i class="material-icons" style="font-size: 30px;">send</i>
          </button>
        </div>
      </form>
    </div>
  </div>
</body>

</html>
<script type="text/JavaScript">
  let originalImage = null
	let ditheredImage = null

	const maxImageWidth = 256
	const maxImageHeight = 128

	let imgWidth = null
	let imgHeight = null

	function checkForDraggingAction(e) {
		let target = e.target

		if (!(target.classList.contains("cropWindowCorner") || target.id === "cropWindow")) {
			return
		}

		target.moving = true

		e.clientX ? // Check if Mouse events exist on user' device
		(target.oldX = e.clientX, // If they exist then use Mouse input
		target.oldY = e.clientY) :
		(target.oldX = e.touches[0].clientX, // otherwise use touch input
		target.oldY = e.touches[0].clientY)

		// get the current size and position of the crop window
		const cropWindow = $("#cropWindow")

		const cropWindowWidth = cropWindow.outerWidth()
		const cropWindowHeight = cropWindow.outerHeight()

		const windowPos = cropWindow.position()
		const left = windowPos.left;
		const top = windowPos.top;

		let overlay = $(".overlay")
		overlay.on("mousemove", draggingAction)
		overlay.on("touchmove", draggingAction)

		function draggingAction(e) {
			e.preventDefault()

			if (!target.moving) {
				return
			}

			let cropWindow = $("#cropWindow")

			let hMargin = imgWidth - cropWindowWidth
			let vMargin = imgHeight - cropWindowHeight

			let newLeft = null
			let newTop = null

			event.clientX ?
			(target.distX = event.clientX - target.oldX,
			target.distY = event.clientY - target.oldY) :
			(target.distX = event.touches[0].clientX - target.oldX,
			target.distY = event.touches[0].clientY - target.oldY)

			if(target.id === "cropWindow") {
				newLeft = left + target.distX < 0
					? 0
					: left + target.distX < hMargin
						? left + target.distX
						: hMargin
				newTop = top + target.distY < 0
					? 0
					: top + target.distY < vMargin
						? top + target.distY
						: vMargin
			} else {


				let changeWidth = (target.id === 'topLeft' || target.id === 'bottomLeft')
					? target.distX * -1
					: target.distX

				let changeHeight = (target.id === 'topLeft' || target.id === 'topRight')
					? target.distY * -1
					: target.distY

				// ensure resizing occurs in proper proportions
				let totalChange = parseInt((changeHeight + changeWidth) / 2)

				// keep the window height between 64 and maxImageHeight
				let newHeight = cropWindowHeight + totalChange < 64
					? 64
					// check if cursor leaves in top left corner
					: target.id === 'topLeft' && (top - totalChange < 0 || left - totalChange * 2 < 0)
						? Math.min(parseInt(left / 2) + cropWindowHeight, top + cropWindowHeight)
						// top right corner
						: target.id === 'topRight' && (top - totalChange < 0 || left + totalChange * 2 > hMargin)
							? Math.min(parseInt((imgWidth - left) / 2), top + cropWindowHeight)
							// bottom right corner
							: target.id === 'bottomRight' && (top + totalChange > vMargin || left + totalChange * 2 > hMargin)
								? Math.min(parseInt((imgWidth - left) / 2), imgHeight - top)
								// bottom left corner
								: target.id === 'bottomLeft' && (top + totalChange > vMargin || left - totalChange * 2 < 0)
									? Math.min(parseInt(left / 2) + cropWindowHeight, imgHeight - top)
									: cropWindowHeight + totalChange > maxImageHeight
										? maxImageHeight
										: cropWindowHeight + totalChange

				newLeft = (target.id === 'topLeft' || target.id === 'bottomLeft')
					? left + (cropWindowHeight - newHeight) * 2
					: left

				newTop = (target.id === 'topLeft' || target.id === 'topRight')
					? top + (cropWindowHeight - newHeight)
					: top

				cropWindow.css( { width: newHeight * 2, height: newHeight })
			}

			cropWindow.css({ left: newLeft, top: newTop })
		}

		function endDrag() {
			target.moving = false
			overlay.off("mouseup", endDrag)
			overlay.off("touchend", endDrag)
			overlay.off("mousemove", draggingAction)
			overlay.off("touchmove", draggingAction)
		}

		overlay.on("mouseup", endDrag)
		overlay.on("touchend", endDrag)
	}



	function closeOverlay() {
		let overlay = $(".overlay")
		overlay.hide()
		overlay.off("mousedown", checkForDraggingAction)
		overlay.off("touchstart", checkForDraggingAction)
	}

	function openOverlay() {
		let overlay = $(".overlay")
		overlay.show()
		// check for
		overlay.on("mousedown", checkForDraggingAction)
		overlay.on("touchstart", checkForDraggingAction)
	}

	function confirmCrop() {
		// get the current size and position of the crop window
		const cropWindow = $("#cropWindow")

		const cropWindowHeight = cropWindow.outerHeight()
		const windowPos = cropWindow.position()

        let formData = new FormData();
		formData.append('imageBlob', originalImage)
        formData.append('x', windowPos.left)
		formData.append('y', windowPos.top)
        formData.append('height', cropWindowHeight)

		$.ajax({
            url: 'cropImage.php',
            type: 'POST',
            data: formData,
            success: function({ imgBlob }, _status) {
				originalImage = imgBlob
				ditherImage({img: originalImage, brightness: 0}, openImgInMsgWindow)
			},
            cache: false,
            contentType: false,
            processData: false
        })

		closeOverlay();
	}

	function openFileSelector() {
		$('#fileSelector').click();
	}

    function ditherImage({img, brightness}, callback) {
        let formData = new FormData();
        formData.append('brightness', brightness)
		formData.append('imageBlob', img)
        $.ajax({
            url: 'createBitmap.php',
            type: 'POST',
            data: formData,
            success: function ({bitMap, imgBlob}, _status) {
                ditheredImage = imgBlob
                callback({bitMap, imgBlob})
            },
            cache: false,
            contentType: false,
            processData: false
        })
    }

	function openImgInMsgWindow({bitMap, imgBlob}) {
		$("#emoji").hide()
		$("#text").hide()
		$("#brightness").show()
		$("#imgPreview").show()
		$("#cancel").show()
		$("#msgType").attr("value", "b")
		$("#bitMap").attr("value", bitMap)
		$("#realImgPreview").attr("src", "data:image/jpg;base64," + imgBlob);
	}

	function increaseBrightness() {
		$("#brightnessInput")[0].stepUp()
		let brightness = $("#brightnessInput").val()
		if(brightness == -9) {
			$("#decBrightButton").show()
		}
		if(brightness == 0) {
			$("#brightnessIcon").text("brightness_4")
		}
		if(brightness == 5) {
			$("#brightnessIcon").text("brightness_5")
		}
		if(brightness == 10) {
			$("#incBrightButton").hide()
		}
        ditherImage({img: originalImage, brightness: brightness * 0.025}, function({bitMap, imgBlob}) {
			$("#bitMap").attr("value", bitMap)
			$("#realImgPreview").attr("src", "data:image/jpg;base64," + imgBlob);
		})
	}

	function decreaseBrightness() {
		$("#brightnessInput")[0].stepDown()
		let brightness = $("#brightnessInput").val()
		if(brightness == -10) {
			$("#decBrightButton").hide()
		}
		if(brightness == -5) {
			$("#brightnessIcon").text("brightness_2")
		}
		if(brightness == 0) {
			$("#brightnessIcon").text("brightness_4")
		}
		if(brightness == 9) {
			$("#incBrightButton").show()
		}
        ditherImage({img: originalImage, brightness: brightness * 0.025}, function({bitMap, imgBlob}) {
			$("#bitMap").attr("value", bitMap)
			$("#realImgPreview").attr("src", "data:image/jpg;base64," + imgBlob);
		})
	}

	$("form.chat_form").on("submit", function(e) {
		e.preventDefault();
		let formData = new FormData(this)
    	formData.append('imageBlob', ditheredImage)
		$.ajax({
            url: 'send.php',
            type: 'POST',
            data: formData,
            success: function (data, status) {
				$(".messages").append(`
				<div class="message" style="order: ${order};">
					${data}
				</div>
				`)
				order--
            },
            cache: false,
            contentType: false,
            processData: false
        })
        clearImage()
		this.reset()
	})

	$('#fileSelector').on("change", function() {
        if(this.files.length === 0) { return }
		let formData = new FormData();
		formData.append('fileToUpload', this.files[0])
		$.ajax({
			url: 'upload.php',
			type: 'POST',
			data: formData,
			success: function ({imgBlob, size}, status) {
				originalImage = imgBlob
				$("#cropImg").attr("src", "data:image/jpg;base64," + originalImage);
				console.log(`Width: ${size.width}, Height: ${size.height}`);
				({ width: imgWidth, height: imgHeight } = size);
				let x_offset = (size.width - maxImageWidth) / 2
				let y_offset = (size.height - maxImageHeight) / 2
				$("#cropWindow").css({ left: x_offset, top: y_offset })
				openOverlay()
			},
			cache: false,
			contentType: false,
			processData: false
		})
	})

	$("#cancel button").on("click", clearImage)

    function clearImage() {
		$("#emoji").show()
		$("#text").show()
		$("#brightness").hide()
		$("#imgPreview").hide()
		$("#cancel").hide()
		$("#msgType").attr("value", "t")
		$("#bitMap").attr("value", "")
	}

	$(document).ready(function() {
		$(".text textarea").on("input propertychange keyup change", function() {
			var text = $(this).val()
			// look for any "\n" occurences
			var breaks = text.match(/\n/g)
			var new_lines = breaks ? breaks.length : 0
			var height = ((new_lines > 1) ? (new_lines + 1) : 2) * 20 + 8
			$(this).attr("rows", new_lines + 1)
			$(".chat_form").css("height", height)
		})
	});
</script>

<style type="text/css">
  @import "styles.css";
</style>
