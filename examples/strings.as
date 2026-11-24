void main()
{
    string text = "AngelScript makes scripting simple";
    array<string>@ words = text.split(" ");
    println("words: " + words.length());
    println("joined: " + join(words, "-"));
    println("first word: " + text.substr(0, 11));
    println("'simple' starts at: " + text.findFirst("simple"));
    println("padded: [" + formatInt(42, "0", 6) + "]");
    println("float: " + formatFloat(3.14159, "", 4, 2));
}
