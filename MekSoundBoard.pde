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

// Internet address -> client struct
long timeoutDuration = 60; // In seconds
float maxRequestsPerTenSeconds = 10;
float minRequestDelta = 100; // In miliseconds

class SoundBoardClient {
  String ip;
  int requestCount = 0;
  long firstRequest = 0;
  long lastRequest = 0;
  boolean timeout = false;
  long startTimeout;

  SoundBoardClient(String ip) {
    this.ip = ip;
    lastRequest = (new Date()).getTime();
    firstRequest = (new Date()).getTime();
  }
}
HashMap<String, SoundBoardClient> clientsMap = new HashMap<String, SoundBoardClient>();

// Rules
int minHour = 8;
int maxHour = 1;

// Sound variables
String[] soundNames;
SoundFile[] soundFiles;

// DEBUG
int errorCount = 0;
String errorBuffer;

void setup() {  
  try {
    server = new Server(this, 80); // start server on http-alt
    String[] htmlFileLines = loadStrings("index.html");
    for (String line : htmlFileLines) {
      if (line == null || line.isEmpty()) { continue; }
      originalHTMLFile += line + "\n";
    }

    doSetup();
  } 
  catch (Exception e) {
    logError("Error: " + e.getMessage());
    exit();
  }
}

void draw() {
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
  if (errorCount > 0) {
    String filename = year() + "-" + month() + "-" + day() + " error log" + random(0.0f, 1.0f) + ".txt";
    PrintWriter errorOutput = createWriter(filename);
    errorOutput.println(errorBuffer);
    errorOutput.flush();
    errorOutput.close();
  }

  server.stop();
}

void doSetup() {
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
        //soundFiles[i].play();
      }
    }
  }
  println(soundFiles.length + " sounds loaded.");

  int btn_count = soundFiles.length;
  String buffer = "";
  for (int i = 0; i < btn_count; i++) {
    buffer += "<button class=\"sfx-btn mdl-button mdl-js-button mdl-button--raised mdl-js-ripple-effect mdl-button--accent\" " + 
      " data-button=\"" + i + "\" >";

    buffer += soundNames[i];
    buffer += "</button>" + "\n\n";
  }

  updatedHTMLFile = originalHTMLFile.replace("{{ buttons }}", buffer);
}

void processClient(Client client) {
  if (client.available() > 0) {
    String request = client.readString();
    if (request.contains("GET / ")) {
      doSetup();

      // Now add the client to the HashMap if it isn't already there.
      String clientIp = client.ip();
      if (!clientsMap.containsKey(clientIp)) {
        clientsMap.put(clientIp, new SoundBoardClient(clientIp));
      }

      client.write(HTTP_HEADER);  // answer that we're ok with the request and are gonna send html  
      client.write(updatedHTMLFile);
      // close connection to client, otherwise it's gonna wait forever
      client.stop();
    } else if (request.contains("GET /PlaySound")) {
      String json = "";
      // Check if we are NOT between 1am and 8am
      // TODO: Make this more robust such that we don't need a ! in the if statement
      // TODO: Get time from a timeserver instead of the local time to prevent users from changing the
      // computer's time.
      int hour = hour();
      if (!(hour >= maxHour && hour < minHour)) {
        // Check if the user is allowed to do a request
        String clientIp = client.ip();
        SoundBoardClient sbClient;
        if (!clientsMap.containsKey(clientIp)) {
          sbClient = clientsMap.put(clientIp, new SoundBoardClient(clientIp));
        } else {
          sbClient = clientsMap.get(clientIp);
        }
        // Check if the user can send
        long timeMs = (new Date()).getTime();
        long dt = timeMs - sbClient.lastRequest;
        println(dt);
        if (dt >= minRequestDelta) {
          // Check if the user, in the last ten seconds (10000ms), has done more than
          // the maximum amount of requests, if so, time out should occur.
          if (sbClient.requestCount > maxRequestsPerTenSeconds) {
            if (timeMs - sbClient.firstRequest >= 10*1000) {
              sbClient.firstRequest = timeMs;
              sbClient.requestCount = 0;
            } else {
              // Don't honnor the request.
              json = "{\"successfull\": false, \"reason\": \"too many requests\"}";
              client.write(json);
              client.stop();
              return;
            }
          }
          sbClient.lastRequest = timeMs;
          sbClient.requestCount++;
          // Do request
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
          }
          // Success!
          client.write("{\"successfull\":" + ((requestSuccesfull)?"true":"false") + "}");
        } else {
          // Too many requests by the same ip within 100 ms
          client.write("{\"successfull\": false, \"reason\": \"timeout\"}");
        }
      } else {
        // It is between maxTime and minTime, such we should not recieve any data.
        client.write("{\"successfull\": false, \"reason\": \"too late\"}");
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