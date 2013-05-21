module engine.locale;

import std.stdio;
import std.file;
import std.conv;
import engine.text.lexer;

void readLocalization(dstring[string] dict, string filename)
{
    enum State
    {
        WaitForKey,
        WaitForValue
    }

    Lexer lex = new Lexer(readText(filename));
    lex.addDelimiters(["\""]);

    State state = State.WaitForKey;
    string key = "";

    string lexeme;
    do
    {
        lexeme = lex.getLexeme();

        if (!lexeme.length)
            break;

        if (state == State.WaitForKey)
        {
            key = lexeme;
            state = State.WaitForValue;
        }
        else
        {
            if (key.length)
            {
                dstring val = lexeme.to!dstring;

                if (val[0] == '\"' && val[$-1] == '\"')
                    val = val[1..$-1];

                dict[key] = val;
                key = "";
                state = State.WaitForKey;
            }
            else throw new Exception("Failed to read localization " ~ filename);
        }
    }
    while(lexeme.length);
}

