import std.stdio, std.string, std.conv, std.process, std.json,
       std.array, std.socket, std.stream, std.socketstream, std.regex;

enum currentDir = "/home/diginatu/Dropbox/share/open_jtalk_read_server/";

void main(string[] args){
  if(args.length < 3) {
    if (args.length == 1) args ~= "引数が足りません";
    else args[1] = "引数が足りません";
    args ~= "add_text";
  }

  try {
    Socket sock = new TcpSocket(new InternetAddress("localhost", 18888));
    scope(exit) sock.close();

    Stream ss = new SocketStream(sock);
    auto controlChar = regex(`[\x00-\x09\x0B\x0C\x0E-\x1F\x7F]`);
    JSONValue mes = [ "message": replaceAll(args[1], controlChar, ""),
              "user_id": replaceAll(args[2], controlChar, "") ];

    ss.writeString(mes.toString());

    return;
  } catch(SocketOSException e) {
    if(e.errorCode == 111) {
      executeShell(`gnome-terminal -e "` ~ currentDir ~ `open_jtalk_read_server" -t "Read Server"`);
    } else {
      writeln(e);
    }
  }
}

