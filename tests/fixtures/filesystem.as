int main()
{
    array<string>@ args = getArgs();
    if (args.length() != 1)
        return 1;

    filesystem fs;
    string dir = args[0];
    if (fs.makeDir(dir) != 0 || !fs.isDir(dir))
        return 1;

    string path = dir + "/sample.txt";
    string content = "file contents";
    file stream;
    if (stream.open(path, "w") != 0 || stream.writeString(content) != int(content.length()) || stream.close() != 0)
        return 1;
    if (stream.open(path, "r") != 0)
        return 1;

    string result = stream.readString(content.length());
    if (stream.close() != 0 || fs.deleteFile(path) != 0 || fs.removeDir(dir) != 0 || result != content)
        return 1;

    println(result);
    return 0;
}
