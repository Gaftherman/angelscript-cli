void main()
{
    array<string>@ args = getArgs();
    println("count=" + args.length());
    for (uint i = 0; i < args.length(); ++i)
        println("[" + args[i] + "]");
}
