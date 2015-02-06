import std.stdio, std.string, std.conv,
	std.array, std.socket, std.stream, std.socketstream;

void main(string[] args){
	Socket sock = new TcpSocket(new InternetAddress("localhost", 18888));
	scope(exit) sock.close();
	Stream ss   = new SocketStream(sock);

	ss.writeString(args[1]);
}

