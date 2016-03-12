import std.stdio, std.file, std.string, std.conv, core.thread, std.json,
       std.array, std.socket, std.stream, std.socketstream,
       std.process, std.regex, std.typecons, std.algorithm;

enum currentDir = "/PathToCurrentDir";
enum dic_file = currentDir ~ "talk_dic";
enum voice_file = "/PathToVoice/a.htsvoice";
enum jtalk_dic_file = "/PathToDic/naist-jdic";
enum jtalk_params = "";
enum openJTalkExec = "open_jtalk -m " ~ voice_file ~ jtalk_params ~
                          " -x " ~ jtalk_dic_file ~
                          " -ow " ~ currentDir ~ "wav";

class eatText : std.process.Thread {
  Tuple!(string, string)[] dic;
  shared Tuple!(string, string)[]* texts;
  Tuple!(string, string) text;

  this(ref shared Tuple!(string, string)[] texts) {
    auto dicf = std.stdio.File(dic_file, "r");
    string line;
    while ((line = dicf.readln()) !is null) {
      auto el = line.strip.split(" = ");
      dic ~= tuple(el[0], el[1]);
    }

    this.texts = &texts;

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

            executeShell("echo '" ~ text ~ "' | " ~ openJTalkExec ~ " & aplay " ~ currentDir ~ "wav");
          } else {
            executeShell("echo '(voice_us1_mbrola)(SayText \"" ~ talkText ~ "\")' | festival --pipe");
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
    if(match(text[0], regex(`^\$`))) {
      auto teach = match(text[0], regex(`^\$def\(\s*([^ ]+)\s*=\s*([^ ]+)\s*\)`));
      if(!teach.empty) {
        auto cap = teach.captures();
        cap.writeln;

        string add = cap[1].toLower();
        auto found = dic.find!"a[0] == b"(add);
        if (!found.empty()) {
          text[0] = found[0][1] ~ "って読んでる";
        } else {
          dic ~= tuple(add, cap[2]);
          text[0] = cap[2] ~ "って読むんだね";
          dic.sort!"a[0].length > b[0].length"();
          std.file.write(dic_file, saveFormat());
        }

        writeln(text[0]);
        return text[0];
      }
    }

    if(text[1] == "broadcaster") {
      text[0] = replaceFirst(text[0], regex(`^/disconnect$`), "放送終わったよ");
      text[0] = replaceFirst(text[0], regex(`^/info 2 .+$`), "コミュ登録ありがとうございます");
      text[0] = replaceFirst(text[0], regex(`^/info 3 `), "");
      text[0] = replaceFirst(text[0], regex(`^/info 6 `), "地震だって。");
      text[0] = replaceFirst(text[0], regex(`^/info 8 `), "");
      text[0] = replaceFirst(text[0], regex(`^/telop on .+$`), "クルーズが来るようですよ！");
      text[0] = replaceFirst(text[0], regex(`^/telop show `), "");
      text[0] = replaceFirst(text[0], regex(`^/telop off$`), "クルーズが終了しました");
      text[0] = replaceFirst(text[0], regex(`^/koukoku show2.+【広告設定されました】(.+さん)\((.+)（クリックしてもっと見る）</u></a>$`), "$1 広告ありがとうございます $2");
      text[0] = replaceFirst(text[0], regex(`^/koukoku show2.+【広告結果】(.+)</u></a>$`), "広告結果だよ。$1");
    }

    text[0] = replaceFirst(text[0], regex(`https?://[\w/:%#\$&\?\(\)~\.=\+\-]+`), "URLだよ");
    text[0] = replaceAll(text[0], regex(`[8８]{3,}`), "パチパチパチ");
    text[0] = replaceAll(text[0], regex(`[wｗ]{2,}`), ",ハハハ,");
    text[0] = replaceAll(text[0], regex(`([^A-Za-z])[wｗ]([^A-Za-z])`), "$1,ハハ,$2");
    text[0] = replaceFirst(text[0], regex(`^[wｗ]([^A-Za-z].*)?$`), "ハハ,$1");
    text[0] = replaceFirst(text[0], regex(`^(.*[^A-Za-z])?[wｗ]$`), "$1,ハハ");
    text[0] = std.array.replace(text[0], "~", "");
    text[0] = std.array.replace(text[0], "_", "");
    text[0] = std.array.replace(text[0], "'", "'\\''");

    writeln(text[0]);
    return text[0];
  }

  bool needToTalk() {
    if(text[0].empty || match(text[0], 
          r"^/(play|cls|vote|hb|telop perm|telop show0|uadpoint|coupon|/)")) {
      writeln("ignoring comment");
      return false;
    }
    return true;
  }

}

void receive(ref shared Tuple!(string, string)[] texts) {
  auto sock = new TcpSocket(AddressFamily.INET);
  scope(exit) sock.close();
  sock.bind(new InternetAddress("localhost", 18888));
  sock.listen(2);

  for(;;) {
    auto cl_sock = sock.accept();
    Stream ss = new SocketStream(cl_sock);

    immutable receivedText = ss.readLine().to!string();
    writeln(receivedText);
    auto mes = receivedText.parseJSON();
    texts ~= tuple(mes["message"].str(), mes["user_id"].str());
  }
}

void main() {
  shared Tuple!(string, string)[] texts;
  auto eatTextThread = new eatText(texts);
  eatTextThread.start();

  receive(texts);
}
