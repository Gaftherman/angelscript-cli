int initialValue()
{
    int initial = 6;
    println("initial value: " + initial); // BP
    return initial;
}

const int base = initialValue();

int doubleValue(int value)
{
    return value * 2;
}

int main()
{
    int total = doubleValue(base);
    println("total: " + total);
    return 0;
}
