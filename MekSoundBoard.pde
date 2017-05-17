import java.net.InetAddress;
import processing.net.*;
import processing.sound.*;

boolean hidden = false;

// Network variables
InetAddress inet;

String HTTP_GET_REQUEST = "GET /";
String HTTP_HEADER = "HTTP/1.0 200 OK\r\nContent-Type: text/html\r\n\r\n";

Server server;
ArrayList<Client> clients = new ArrayList<Client>();

String originalHTMLFile;
String updatedHTMLFile;

byte EOF = 3;

// Sound variables
String[] soundNames;
SoundFile[] soundFiles;

void setup() {
  String ip = "localhost";
  try {
    inet = InetAddress.getLocalHost();
    ip = inet.getHostAddress();
  }
  catch (Exception e) {}
  println(ip);
  
  server = new Server(this, 80); // start server on http-alt
  println("IP: " + server.ip());
  String[] htmlFileLines = loadStrings("index.html");
  for (String line : htmlFileLines) {
    originalHTMLFile += line;
  }
  
  doSetup();
}

void draw() {
  if(!hidden) {
    surface.setVisible(false);
    hidden = true;
  }
  Client nextClient = server.available();
  while (nextClient != null) {
    processClient(nextClient);
    nextClient = server.available();
  }
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
    buffer += "<button class=\"mdl-button mdl-js-button mdl-button--raised mdl-js-ripple-effect mdl-button--accent\" " + 
              " onclick=\"post(" + i + ")\" >";
    
    buffer += soundNames[i];
    buffer += "</button>" + "\n\n";
  }
  
  updatedHTMLFile = originalHTMLFile.replace("{{ buttons }}", buffer);
}

void processClient(Client client) {
  if (client.available() > 0) {
    String request = client.readString();
    println(client.ip() + " sais: " + request);
    if (request.contains("GET / ")) {
      doSetup();
      client.write(HTTP_HEADER);  // answer that we're ok with the request and are gonna send html  
      client.write(updatedHTMLFile);
      // close connection to client, otherwise it's gonna wait forever
      client.stop();
    } else if (request.contains("GET /PlaySound")) {
      String firstLine = request.substring(0, request.indexOf('\n'));
      println("Request: " + firstLine);
      String[] id = match(firstLine, "/PlaySound/(\\d+)");
      if (id.length > 0) {
        int soundIndex = parseInt(id[1]);
        if (soundIndex >= 0 && soundIndex < soundFiles.length) {
          soundFiles[soundIndex].play();
        }
      }
      client.write("true");
    }
  }
  client.stop();
}