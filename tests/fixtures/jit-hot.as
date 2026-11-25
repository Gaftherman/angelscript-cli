// Runs the same function enough times for a JIT to compile it, then makes it index past the end of an array.
int sum(array<int>@ values, int count)
{
    int total = 0;
    for (int i = 0; i < count; i++)
        total += values[i];
    return total;
}

int main()
{
    array<int> values(100);
    for (int round = 0; round < 3000; round++)
        sum(values, 100);
    return sum(values, 101);
}
