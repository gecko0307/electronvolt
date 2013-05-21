/*
 * Copyright (c) 2011-2013 Timur Gafarov
 *
 * The MIT License
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy 
 * of this software and associated documentation files (the "Software"), to deal 
 * in the Software without restriction, including without limitation the rights 
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies 
 * of the Software, and to permit persons to whom the Software is furnished to do so, 
 * subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in 
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, 
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN 
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE
 */

module engine.text.conf;

private
{
    import std.stdio;
    import std.file;
    import engine.text.lexer;
}

version(Windows) string OS = "windows";
version(linux) string OS = "linux";

final class Config
{
    string[string] data;

    bool has(string key, bool platformSpecific = true)
    {
        if (platformSpecific)
        {
            string oskey = OS ~ "." ~ key;
            if (oskey in data) return true;
        }
        if (key in data) return true;
        else return false;
    }

    string get(string key, bool platformSpecific = true)
    {
        if (platformSpecific)
        {
            string oskey = OS ~ "." ~ key;
            if (oskey in data) return data[oskey];
        }
        if (key in data) return data[key];
        else return "";
    }

    /*
     * TODO: The following should be rewrote in more clever way...
     */
    void set(string key, string value, bool platformSpecific = true)
    {
        if (platformSpecific)
        {
            if (key.length > 7 && (key[0..7] == "windows" || key[0..5] == "linux"))
            {
            }
            else
            {
                string oskey = OS ~ "." ~ key;
                data[oskey] = value;
            }
        }
        data[key] = value;
    }

    void append(string key, string value, bool platformSpecific = true)
    {
        if (platformSpecific)
        {
            if (key.length > 7 && (key[0..7] == "windows" || key[0..5] == "linux"))
            {
            }
            else
            {
                string oskey = OS ~ "." ~ key;
                data[oskey] ~= value;
            }
        }
        data[key] ~= value;
    }
}

/*
 * Parse configuration file
 */

enum
{
    tIdentifier,
    tColon,
    tValue,
    tSemicolon
}

void readConfiguration(Config options, string filename)
{
    auto text = readText(filename);
    auto lex = new Lexer(text);
    lex.addDelimiters();
    auto nextToken = tIdentifier;
    string tempId = "_default_";

    string lexeme = "";
    do 
    {
        lexeme = lex.getLexeme();
        if (lexeme.length > 0)
        {
            if (lexeme == ";")
            {
                if (nextToken == tSemicolon)
                    nextToken = tIdentifier;
                else throw new Exception("unexpected \"" ~ lexeme ~ "\"");
            }
            else if (lexeme == ":")
            {
                if (nextToken == tColon)
                    nextToken = tValue;
                else throw new Exception("unexpected \"" ~ lexeme ~ "\"");
            }
            else
            {
                if (nextToken == tIdentifier) 
                {
                    tempId = lexeme;
                    nextToken = tColon;
                }
                else if (nextToken == tValue) 
                {
                    if (lexeme[0] == '\"' && lexeme[$-1] == '\"')
                    {
                        if (lexeme.length > 2)
                            options.set(tempId, lexeme[1..$-1]);
                        else options.set(tempId, "");
                    }
                    else options.set(tempId, lexeme);
                    tempId = "_default_";
                    nextToken = tSemicolon;
                }
                else throw new Exception("unexpected \"" ~ lexeme ~ "\"");
            }
        }
    } 
    while (lexeme.length > 0);
}

string formatPattern(string pat, Config data, dchar formattingSymbol)
{
    string result;
    string temp;
    bool appending = true;
    foreach(c; pat)
    {
        if (c == formattingSymbol) 
        {
            if (appending)
            {
                appending = false;
            }
            else
            {
                appending = true;
                if (data.has(temp))
                    result ~= formatPattern(data.get(temp), data, formattingSymbol); //data[temp]
                temp = "";
            }
        }
        else
        {
            if (appending) result ~= c;
            else temp ~= c;
        }
    }
    return result;
}

