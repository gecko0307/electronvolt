module engine.wrnd;

import std.traits;
import std.random;
import std.algorithm;

T weightedRandomEnum(T, W)()
    if (isNumeric!W &&
        is(T == enum) && is(W == enum) && 
        EnumMembers!T.length == EnumMembers!W.length)
{
    enum members = [EnumMembers!T];
    enum weights = [EnumMembers!W];
    enum weightsSum = reduce!("a + b")([EnumMembers!W]);
    
    auto randomNumber = uniform(0, weightsSum);
    
    foreach(i, weight; weights)
    {
        if (randomNumber < weight)
            return members[i];
        else
            randomNumber -= weight;
    }
    
    assert(0, "Should never get here");
}

unittest
{
    enum Color
    {
        Red, 
        Yellow, 
        Green, 
        Blue
    }

    enum Weights
    {
        Red = 5, 
        Yellow = 20, 
        Green = 20, 
        Blue = 100
    }

    foreach(i; 0..10)
        writeln(weightedRandomEnum!(Color, Weights));
}
