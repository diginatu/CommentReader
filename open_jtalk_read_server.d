import std.stdio, std.file, std.string, std.conv, core.thread,
	std.array, std.socket, std.stream, std.socketstream,
	std.process, std.regex, std.typecons, std.algorithm;

enum dic_file = "talk_dic";
enum openJTalkExec = "open_jtalk -m [learned file] -x [dictionary] -ow wav";

class eatText : std.process.Thread {
  Tuple!(string, string)[] dic;
  shared string[]* texts;
  string text;

	this(shared string[]* texts) {
    auto dicf = std.stdio.File(dic_file, "r");
    string line;
    while ((line = dicf.readln()) !is null) {
      auto el = line.strip.split(" = ");
      dic ~= tuple(el[0], el[1]);
    }

    this.texts = texts;

		super(&eat);
	}

	void eat() {
    eatLoop();
	}

  void eatLoop() {
    import std.ascii;
		for(;;) {
			if((*texts).empty) {
				sleep( dur!("msecs")( 500 ) );
			} else {
        text = (*texts).front;
        text.writeln();
        (*texts) = (*texts)[1 .. $];

        if(needToTalk()) {
          string talkText = toTalk();
          if(talkText.any!(a => !a.isASCII())()) {
            // replace with dic
            string text = std.string.toLower(talkText);
            foreach(Tuple!(string, string) ln; dic)
              text = std.array.replace(text, ln[0], ln[1]);

            system("echo '" ~ text ~ "' | " ~ openJTalkExec ~ " & aplay wav");
          } else {
            system("echo '(SayText \"" ~ talkText ~ "\")' | festival --pipe");
          }
        }

			}
		}
  }

  string saveFormat() {
    string f;
    foreach(Tuple!(string, string) ln; dic) {
      f ~= ln[0].toLower() ~ " = " ~ ln[1].tr("ぁ-ん","ァ-ン") ~ "\n";
    }
    return f;
  }

  string toTalk() {
    if(match(text, regex(`^\$`))) {
      auto teach = match(text, regex(`^\$def\(([^ ]+) ?= ?([^ ]+)\)`));
      if(!teach.empty) {
        auto cap = teach.captures();
        cap.writeln;

        string add = cap[1].toLower();
        auto found = dic.find!"a[0] == b"(add);
        if (!found.empty()) {
          text = found[0][1] ~ "って読んでる";
        } else {
          dic ~= tuple(add, cap[2]);
          text = cap[2] ~ "って読むんだね";
          dic.sort!"a[0].length > b[0].length"();
          std.file.write(dic_file, saveFormat());
        }

        writeln(text);
        return text;
      }
    }

    text = replaceFirst(text, regex(`^/disconnect$`), "放送終わったよ");
    text = replaceFirst(text, regex(`^/info 2.+$`), "コミュ登録ありがとうございます");

    text = replaceFirst(text, regex(`https?://[\w/:%#\$&\?\(\)~\.=\+\-]+`), "URLだよ");
    text = replaceAll(text, regex(`[8８]{3,}`), "パチパチパチ");
    text = replaceAll(text, regex(`[wｗ]{2,}`), ",ハハハ,");
    text = replaceAll(text, regex(`([^A-Za-z])[wｗ]([^A-Za-z])`), "$1,ハハ,$2");
    text = replaceFirst(text, regex(`^[wｗ]([^A-Za-z].*)?$`), "ハハ,$1");
    text = replaceFirst(text, regex(`^(.*[^A-Za-z])?[wｗ]$`), "$1,ハハ");
    text = std.array.replace(text, "~", "");
    text = std.array.replace(text, "_", "");

    writeln(text);
    return text;
  }

  bool needToTalk() {
    if(text.empty || match(text, r"^/(play|cls|/)")) {
      writeln("ignoring comment");
      return false;
    }
    return true;
  }

}

void receive(ref shared string[] texts) {
	auto sock = new TcpSocket(AddressFamily.INET);
	scope(exit) sock.close();
	sock.bind(new InternetAddress("localhost", 18888));
	sock.listen(2);

	for(;;) {
		auto cl_sock = sock.accept();
		Stream ss = new SocketStream(cl_sock);

		immutable receivedText = ss.readLine().to!string();
		texts ~= receivedText;
	}
}

void main() {
  shared string[] texts;
	auto eatTextThread = new eatText(&texts);
	eatTextThread.start();

	receive(texts);
}
