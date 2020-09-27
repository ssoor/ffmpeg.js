
var worker;
var sampleFiles = {};
var sampleImageData;
var sampleVideoData;
var outputElement;
var filesElement;
var filesReaderElement;
var renderElement;
var running = false;
var isWorkerLoaded = false;
var isSupported = (function () {
  return document.querySelector && window.URL && window.Worker;
})();

function isReady() {
  return !running && isWorkerLoaded && sampleImageData && sampleVideoData;
}

function startRunning() {
  document.querySelector("#image-loader").style.visibility = "visible";
  outputElement.className = "";
  filesElement.innerHTML = "";
  renderElement.innerHTML = "";
  running = true;
}
function stopRunning() {
  document.querySelector("#image-loader").style.visibility = "hidden";
  running = false;
}

function retrieveSampleFiles() {
  var files = ["sample.vtt", "sample.mp4",];
  files.forEach(file => {
    var oReq = new XMLHttpRequest();
    oReq.open("GET", file, true);
    oReq.responseType = "arraybuffer";

    oReq.onload = function (oEvent) {
      var arrayBuffer = oReq.response;
      if (arrayBuffer) {
        sampleFiles[file] = new Uint8Array(arrayBuffer);
      }
    };

    oReq.send(null);
  });
}

function retrieveSampleImage() {
  var oReq = new XMLHttpRequest();
  oReq.open("GET", "bigbuckbunny.jpg", true);
  oReq.responseType = "arraybuffer";

  oReq.onload = function (oEvent) {
    var arrayBuffer = oReq.response;
    if (arrayBuffer) {
      sampleImageData = new Uint8Array(arrayBuffer);
    }
  };

  oReq.send(null);
}

function retrieveSampleVideo() {
  var oReq = new XMLHttpRequest();
  oReq.open("GET", "bigbuckbunny.webm", true);
  oReq.responseType = "arraybuffer";

  oReq.onload = function (oEvent) {
    var arrayBuffer = oReq.response;
    if (arrayBuffer) {
      sampleVideoData = new Uint8Array(arrayBuffer);
    }
  };

  oReq.send(null);
}

function parseArguments(text) {
  text = text.replace(/\s+/g, ' ');
  var args = [];
  // Allow double quotes to not split args.
  text.split('"').forEach(function (t, i) {
    t = t.trim();
    if ((i % 2) === 1) {
      args.push(t);
    } else {
      args = args.concat(t.split(" "));
    }
  });
  return args;
}


function runCommand(text) {
  if (isReady()) {
    startRunning();
    var args = parseArguments(text);
    console.log(args);
    worker.postMessage({
      type: "run",
      arguments: args,
      fs: {
        "mems": [
          {
            "name": "input.jpeg",
            "data": sampleImageData
          },
          {
            "name": "input.webm",
            "data": sampleVideoData
          },
          {
            "name": "sample.vtt",
            "data": sampleFiles["sample.vtt"]
          },
          {
            "name": "sample.mp4",
            "data": sampleFiles["sample.mp4"]
          }
        ],
        "files": filesReaderElement.files
      }
    });
  }
}

function getDownloadLink(fileName, src) {
  var a = document.createElement('a');
  a.download = fileName;
  a.href = src;
  a.textContent = 'Click here to download ' + fileName + "!";
  return a;
}

function getRenderElement(fileName, src) {
  if (fileName.match(/\.jpeg|\.gif|\.jpg|\.png/)) {
    var img = document.createElement('img');
    img.src = src;
    return img;
  } else if (fileName.match(/\.mp4|\.avi|\.mkv|\.webm|\.aac|\.mp3/)) {
    var video = document.createElement('video');
    video.src = src;
    video.controls = "controls";
    return video;
  } else if (fileName.match(/\.wav|\.ogg|\.acc|\.mp3|\.aac|\.mp3/)) {
    var video = document.createElement('video');
    video.src = src;
    video.controls = "controls";
    return video;
  }
}

function initWorker() {
  time = Date.now();
  worker = new Worker('../ffmpeg-web.js');
  worker.onmessage = function (event) {
    var message = event.data;
    if (message.type == "ready") {
      isWorkerLoaded = true;
      worker.postMessage({
        type: "run",
        arguments: ["-help"]
      });
    } else if (message.type == "stderr") {
      outputElement.textContent += message.data + "\n";
    } else if (message.type == "stdout") {
      outputElement.textContent += message.data + "\n";
    } else if (message.type == "start") {
      outputElement.textContent = "Worker has received command\n";
    } else if (message.type == "done") {
      totalTime = Date.now(); - time;
      outputElement.textContent += 'Finished processing (took ' + totalTime + 'ms)\n';

      stopRunning();
      var result = message.data.files;
      if (result.length) {
        outputElement.className = "closed";
      }
      result.forEach(function (file) {
        var blob = new Blob([file.data]);
        var src = window.URL.createObjectURL(blob);
        filesElement.appendChild(getDownloadLink(file.name, src));
        renderElement.appendChild(getRenderElement(file.name, src));
      });
    }
  };
}

document.addEventListener("DOMContentLoaded", function () {

  initWorker();
  retrieveSampleFiles();
  retrieveSampleVideo();
  retrieveSampleImage();

  var inputElement = document.querySelector("#input");
  outputElement = document.querySelector("#output");
  filesElement = document.querySelector("#files");
  renderElement = document.querySelector("#render");
  filesReaderElement = document.querySelector("#files-reader");

  inputElement.addEventListener("keydown", function (e) {
    if (e.keyCode === 13) {
      runCommand(inputElement.value);
    }
  }, false);
  document.querySelector("#run").addEventListener("click", function () {
    runCommand(inputElement.value);
  });

  [].forEach.call(document.querySelectorAll(".sample"), function (link) {
    link.addEventListener("click", function (e) {
      inputElement.value = this.getAttribute("data-command");
      runCommand(inputElement.value);
      e.preventDefault();
    });
  });

});