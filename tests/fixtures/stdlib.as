int main()
{
    array<int> values = {int(sqrt(81.0f)), 2};
    dictionary totals;
    totals.set("sum", int64(values[0]));

    int64 sum;
    if (!totals.get("sum", sum))
        return 1;

    array<string> parts = {"sum", "" + sum};
    println(join(parts, "="));
    return 0;
}
