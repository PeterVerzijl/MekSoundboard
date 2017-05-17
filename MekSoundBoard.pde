import java.util.Date;
import processing.net.*;
import processing.sound.*;

boolean hidden = false;

// Network variables
String HTTP_GET_REQUEST = "GET /";
String HTTP_HEADER = "HTTP/1.0 200 OK\r\nContent-Type: text/html\r\n\r\n";

Server server;
ArrayList<Client> clients = new ArrayList<Client>();

String originalHTMLFile;
String updatedHTMLFile;

// Sound variables
String[] soundNames;
SoundFile[] soundFiles;

// DEBUG
int errorCount = 0;
String errorBuffer;

void setup() {  
  // Try to create a server and load the index.html file.
  try {
    server = new Server(this, 80); // start server on http-alt
    String[] htmlFileLines = loadStrings("index.html");
    for (String line : htmlFileLines) {
      originalHTMLFile += line;
    }
    // Load audio and update index.html
    doSetup();
  } 
  catch (Exception e) {
    logError("Error: " + e.getMessage());
    exit();
  }
}

void draw() {
  // Catch all :P
  try {
    if (!hidden) {
      surface.setVisible(false);
      hidden = true;
    }
    Client nextClient = server.available();
    while (nextClient != null) {
      processClient(nextClient);
      nextClient = server.available();
    }
  } 
  catch (Exception e) {
    logError("Error: " + e.getMessage());
    exit();
  }
}

void stop() {
  // If there are any errors, output them to the error file.
  if (errorCount > 0) {
    String filename = year() + "-" + month() + "-" + day() + " error log" + random(0.0f, 1.0f) + ".txt";
    PrintWriter errorOutput = createWriter(filename);
    errorOutput.println(errorBuffer);
    errorOutput.flush();
    errorOutput.close();
  }
  // Gracefully stop the server.
  server.stop();
}

/**
* Loads all audio files in the .\data\sounds\ folder. This function
* also updates the index.html file by populating the correct buttons.
*/
void doSetup() {
  // Load all audio files
  String path = sketchPath() + "\\data\\sounds\\";
  File folder = new File(path);
  if (folder.exists()) {
    File[] listOfFiles = folder.listFiles();

    soundFiles = new SoundFile[listOfFiles.length];
    soundNames = new String[listOfFiles.length];

    for (int i = 0; i < listOfFiles.length; i++) {
      if (listOfFiles[i].isFile()) {
        println("File " + listOfFiles[i].getName() + " loaded.");
        String name = listOfFiles[i].getName();
        name = name.replace(".wav", "");
        name = name.replace(".mp3", "");
        soundNames[i] = name;
        soundFiles[i] = new SoundFile(this, "\\sounds\\" + listOfFiles[i].getName());
      }
    }
  }
  println(soundFiles.length + " sounds loaded.");
  
  // Generate all the buttons for the sounds
  int btn_count = soundFiles.length;
  String buffer = "";
  for (int i = 0; i < btn_count; i++) {
    buffer += "<button class=\"mdl-button mdl-js-button mdl-button--raised mdl-js-ripple-effect mdl-button--accent\" " + 
      " onclick=\"post(" + i + ")\" >";

    buffer += soundNames[i];
    buffer += "</button>" + "\n\n";
  }
  updatedHTMLFile = originalHTMLFile.replace("{{ buttons }}", buffer);
}

/**
* Processes a client when a client is sending data to the sever. For now this can be two tings:
*   a: The client is sending a plane GET request for the path / where we reply with the HTML file.
*   b: The client is sending a GET for a specific index of soudn: GET /PlaySound/<index/name>
       in this case we reply with a true, or false depending on if the index/name is valid.
*/
void processClient(Client client) {
  if (client.available() > 0) {
    String request = client.readString();
    if (request.contains("GET / ")) {
      doSetup();
      
      client.write(HTTP_HEADER);  // answer that we're ok with the request and are gonna send html  
      client.write(updatedHTMLFile);
      // close connection to client, otherwise it's gonna wait forever
      client.stop();
    } else if (request.contains("GET /PlaySound")) {
      boolean requestSuccesfull = false;
      String firstLine = request.substring(0, request.indexOf('\n'));
      if (firstLine != null) {
        String[] id = match(firstLine.trim(), "/PlaySound/(\\d+)");
        if (id != null && id.length > 0) {
          if (isNumeric(id[1])) {
            int soundIndex;
            try {
              soundIndex = Integer.parseInt(id[1]);
              if (soundIndex >= 0 && soundIndex < soundFiles.length) {
                soundFiles[soundIndex].play();
                requestSuccesfull = true;
              }
            } 
            catch (NumberFormatException e) {
              logError("Error: " + e.getMessage());
            }
          }
        } else {
          firstLine = firstLine.replace("%20", " ");
          // Not numeric, check if it is one of the filenames
          for (int i = 0; i < soundNames.length; i++) {
            String filename = soundNames[i];
            if (firstLine.contains(filename)) {
              soundFiles[i].play();
              requestSuccesfull = true;
              break;
            }
          }
        }
        client.write((requestSuccesfull)?"true":"false");
      }
    }
  }
  client.stop();
}

void logError(String error) {
  errorBuffer += "Error: " + error + "\n";
  errorCount++;
}

boolean isNumeric(String str) {
  boolean result = false;
  if (str != null) {
    result = str.matches("-?\\d+(\\.\\d+)?");  //match a number with optional '-' and decimal.
  }
  return result;
}