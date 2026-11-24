void main()
{
    filesystem fs;
    fs.makeDir("demo-dir");
    array<string> names = {"gamma.txt", "alpha.txt", "beta.txt"};
    for (uint i = 0; i < names.length(); i++)
    {
        file f;
        f.open("demo-dir/" + names[i], "w");
        f.writeString("x");
        f.close();
    }

    fs.changeCurrentPath("demo-dir");
    array<string>@ found = fs.getFiles();
    found.sortAsc();
    for (uint i = 0; i < found.length(); i++)
        println(found[i]);

    fs.changeCurrentPath("..");
    for (uint i = 0; i < names.length(); i++)
        fs.deleteFile("demo-dir/" + names[i]);
    fs.removeDir("demo-dir");
}
