module main;

import std.stdio;
import std.file;
import std.string;

struct DicWord
{
	string eng;
	string eng2;
	bool validated;
}

int main(string[] argv)
{
	try
	{
		if(argv.length < 3 || argv[1] == "help" || argv[1] == "--help" || argv[1] == "-?" || argv[1] == "/?")
		{
			writeln("English 2.0 translation tool.\nUsage:\n  eng2trans trans <text> [dictionary]  Translate the text using the specified\n                                       dictionary.");
		}
		else if(argv[1] == "trans")
		{
			translate(argv[2], argv.length > 3 ? argv[3] : "words.txt");
		}
	}
	catch
	{

	}

	return 0;
}

void translate(string textFile, string dic)
{
	DicWord[] dictionary = loadDic(dic);

	string text = cast(string)read(textFile);

	//...

	saveDic(dictionary, dic);
}

DicWord[] loadDic(string dic)
{
	string bytes = cast(string)read(dic);
	string[] lines = splitLines(bytes);

	DicWord[] words;
	foreach(l; lines)
	{
		auto elements = split(l, ",");
		if(elements.length == 0)
			continue;

		string eng = elements[0].idup;
		string eng2 = elements.length >= 2 ? elements[1].idup : guessWord(eng);
		bool validated = elements.length >= 3 && elements[2][0] == 'v';

		words ~= DicWord(eng, eng2, validated);
	}
	return words;
}

void saveDic(DicWord[] dictionary, string dic)
{
	char[] csv;
	foreach(w; dictionary)
		csv ~= w.eng ~ (w.validated ? "," ~ w.eng2 ~ ",v\n" : "\n");

	std.file.write(dic, csv);
}

string guessWord(string word)
{
	struct Tr { string match, replace; }
	immutable Tr startsWith[] =
	[
		{ "awe", "å" },
		{ "an", "än" },
	];
	immutable Tr endsWith[] =
	[
		{ "re", "r" },
		{ "ise", "aiz" },
		{ "ize", "aiz" },
		{ "able", "abl" },
		{ "tion", "shon" },
		{ "tion", "shon" },
		{ "y", "i" },
	];
	immutable Tr contains[] =
	[
		{ "ore", "år" },
		{ "ire", "air" },
		{ "ge", "je" },

		{ "and", "änd" },
		{ "ant", "änt" },
		{ "ang", "äng" },
		{ "at", "ät" },

		{ "theo", "þio" },
		{ "there", "ðer" },
		{ "them", "ðem" },
		{ "ther", "þer" },
		{ "th", "þ" },
		{ "tio", "sho" },
		{ "ph", "f" },
		{ "qu", "ku" },
		{ "igh", "ai" },
		{ "ought", "ååt" },
		{ "ee", "ii" },
		{ "oon", "üün" },
		{ "oop", "üüp" },
		{ "ook", "uk" },
		{ "oi", "åi" },
		{ "ain", "äin" },
		{ "er", "ör" },
		{ "ogi", "oji" },
		{ "ogy", "oji" },
		{ "bush", "bush" },
		{ "cush", "kush" },
		{ "ush", "ash" },

		{ "cce", "ks" },
		{ "cc", "kk" },
		{ "ces", "ses" },
		{ "ce", "s" },
		{ "ch", "c" },
		{ "ci", "si" },
		{ "ck", "k" },
		{ "cz", "sz" },
		{ "cy", "sai" },
		{ "c", "k" },
	];

	string w = word;

	foreach(ref t; startsWith)
	{
		size_t len = t.match.length;
		if(len <= w.length && w[0..len] == t.match)
		{
			w = t.replace ~ w[len..$];
			break;
		}
	}

	foreach(ref t; endsWith)
	{
		size_t len = t.match.length;
		if(len <= w.length && w[$-len..$] == t.match)
		{
			w = w[0..$-len] ~ t.replace;
			break;
		}
	}

	for(size_t i = 0; i < w.length; ++i)
	{
		size_t wl = w.length;

		foreach(ref t; contains)
		{
			size_t e = i+t.match.length;
			if(e <= wl && w[i..e] == t.match)
			{
				w = w[0..i] ~ t.replace ~ w[e..$];
				break;
			}
		}
	}

	return w;
}
