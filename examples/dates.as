void main()
{
    datetime launch(2026, 11, 24, 9, 30, 0);
    datetime later = launch + 90 * 60;
    println("year " + launch.year + ", month " + launch.month + ", day " + launch.day);
    println("later: " + later.hour + ":" + later.minute);
    println("seconds apart: " + (later - launch));
    println(launch < later ? "launch comes first" : "later comes first");
}
