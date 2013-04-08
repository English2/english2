module eng2trans;

import std.stdio;
import std.file;
import std.string;
import std.uni;
import std.utf;
import std.algorithm;

version(Windows)
{
	import std.c.windows.windows;
	extern(Windows) BOOL WriteConsoleW(HANDLE, const WCHAR*, DWORD, LPDWORD, LPVOID);
	extern(Windows) BOOL ReadConsoleW(HANDLE, WCHAR*, DWORD, LPDWORD, LPVOID);
	extern(Windows) HANDLE GetStdHandle(DWORD nStdHandle);
	enum STD_INPUT_HANDLE = cast(DWORD)-10;
	enum STD_OUTPUT_HANDLE = cast(DWORD)-11;

	wstring readConsole()
	{
		static wchar[2048] buffer;
		DWORD l;
		ReadConsoleW(GetStdHandle(STD_INPUT_HANDLE), buffer.ptr, cast(DWORD)buffer.length, &l, null);
		return buffer[0..l].idup;
	}

	size_t writeConsole(wstring text)
	{
		HANDLE stdout = GetStdHandle(STD_OUTPUT_HANDLE);
		DWORD l, l2;
		WriteConsoleW(stdout, text.ptr, cast(DWORD)text.length, &l, null);
		text = "\n"w;
		WriteConsoleW(stdout, text.ptr, cast(DWORD)text.length, &l2, null);
		return l + l2;
	}
}
else
{
	wstring readConsole()
	{
		string s = readln();
		return s.toUTF16;
	}

	size_t writeConsole(wstring text)
	{
		writeln(text.toUTF8);
		return text.length;
	}
}

struct DicWord
{
	wstring eng;
	wstring eng2;
	bool validated;
	bool dubious;
}

struct Options
{
	enum Action
	{
		Unknown,

		Translate,
		Reconsider
	}

	Action action;

	bool showHelp;
	bool askMissing;

	string input;
	string output = "trans.txt";
	string dictionary = "words.txt";
	string missing = "missing.txt";
}


int main(string[] argv)
{
	try
	{
		Options options;

		foreach(arg; argv[1..$])
		{
			if(arg.length >= 2)
			{
				if(arg[0..2] == "--")
				{
					// full word options
					switch(arg[2..$])
					{
						case "help":
							options.showHelp = true;
							break;
						default:
					}
					continue;
				}
				else if(arg[0] == '-' || arg[0] == '/')
				{
					// single letter options
					foreach(c; arg[1..$])
					{
						switch(c)
						{
							case 'h':
							case '?':
								options.showHelp = true;
								break;
							case 'm':
								options.askMissing = true;
								break;
							default:
						}
					}
					continue;
				}
			}
			if((arg == "trans" || arg == "translate") && options.action == Options.Action.Unknown)
			{
				options.action = Options.Action.Translate;
			}
			else if(arg == "reconsider" && options.action == Options.Action.Unknown)
			{
				options.action = Options.Action.Reconsider;
			}
			else if(options.action == Options.Action.Unknown)
			{
				// bad args, we'll just show the help?
				options.showHelp = true;
				break;
			}
			else
			{
				if(!options.input)
					options.input = arg;
				else if(!options.output)
					options.output = arg;
				else if(!options.dictionary)
					options.dictionary = arg;
				else if(!options.missing)
					options.missing = arg;
			}
		}

		if(options.showHelp)
		{
			writeln("English 2.0 translation tool.\nUsage:\n  eng2trans trans <text> [dictionary]  Translate the text using the specified\n                                       dictionary.");
		}
		else if(options.action == Options.Action.Translate)
		{
			translate(options);
		}
		else if(options.action == Options.Action.Reconsider)
		{
			// load the dictionary and reconsider dubious words
		}
	}
	catch
	{

	}

	return 0;
}

void translate(ref in Options options)
{
	DicWord[] dictionary = loadDic(options.dictionary);
	wstring[] missing;

	string loadText = cast(string)read(options.input);

	wstring text = loadText.toUTF16;
	wchar[] translated = new wchar[text.length*2];
	size_t len;

	while(text.length)
	{
		size_t wordLen = 1;

		if(isAlpha(text[0]))
		{
			bool unknownCaps;
			bool startsUpper = isUpper(text[0]);
			bool allUpper = startsUpper;

			while(wordLen < text.length && text[wordLen].isAlpha)
			{
				bool upper = text[wordLen].isUpper;
				unknownCaps = unknownCaps || (allUpper && !startsUpper && !upper) || (startsUpper && upper);
				allUpper = allUpper && upper;
				startsUpper = startsUpper && !upper;
				++wordLen;
			}

			wstring word = text[0 .. wordLen];

			// find word in dictionary
			DicWord* w = findWord(word, dictionary);
			if(w && !unknownCaps && (w.validated || options.askMissing))
			{
				if(!w.validated)
				{
					// confirm translation
					writeConsole("Confirm translation for '"w ~ w.eng ~ "': "w ~ w.eng2);
					wstring t = readConsole().strip;
					if(t.length && t[$-1] == '?')
					{
						w.dubious = true;
						t = t[0..$-1];
					}
					if(t.length)
						w.eng2 = t;
					w.validated = true;
				}

				word = w.eng2;
			}
			else
			{
				if(!unknownCaps)
					word = word.toLower;

				// see if it's already in the missing list
				auto x = find!("!icmp(a,b)")(missing, word);
				if(!x.length)
				{
					if(options.askMissing)
					{
						// ask for translation
						writeConsole("Word not in dictionary: "w ~ word);
						wstring t = readConsole().strip;

						DicWord newWord;
						if(t.length && t[$-1] == '?')
						{
							newWord.dubious = true;
							t = t[0..$-1];
						}
						if(t.length)
						{
							newWord.eng = word;
							newWord.eng2 = t;
							word = t;
							newWord.validated = true;

							dictionary ~= newWord;
						}
						else
							missing ~= word;
					}
					else
						missing ~= word;
				}
			}

			translated[len .. len+word.length] = word;

			// correct case...
			if(startsUpper)
				translated[len] = cast(wchar)translated[len].toUpper;
			else if(allUpper)
			{
				foreach(ref c; translated[len .. len+word.length])
					c = cast(wchar)c.toUpper;
			}

			len += word.length;
		}
		else
		{
			while(wordLen < text.length && !text[wordLen].isAlpha)
				++wordLen;
			translated[len .. len+wordLen] = text[0 .. wordLen];
			len += wordLen;
		}

		text = text[wordLen .. $];
	}

	translated = translated[0 .. len];
	std.file.write(options.output, translated.toUTF8);

	saveDic(dictionary, options.dictionary);
}

DicWord[] loadDic(string dic)
{
	scope(failure) return null;

	string bytes = cast(string)read(dic);
	string[] lines = splitLines(bytes);

	DicWord[] words;
	foreach(l; lines)
	{
		auto elements = split(l, ",");
		if(elements.length == 0)
			continue;

		wstring eng = elements[0].toUTF16;
		wstring eng2 = elements.length >= 2 ? elements[1].toUTF16 : guessWord(eng);

		bool validated, dubious;
		if(elements.length >= 3)
		{
			validated = elements[2][0] == 'v';
			dubious = elements[2].length >= 2 && elements[2][1] == '?';
		}

		words ~= DicWord(eng, eng2, validated, dubious);
	}
	return words;
}

void saveDic(DicWord[] dictionary, string dic)
{
	scope(failure) return;

	char[] csv;
	foreach(w; dictionary)
		csv ~= w.eng.toUTF8 ~ (w.validated ? "," ~ w.eng2.toUTF8 ~ ",v" ~ (w.dubious ? "?" : "") ~ "\n" : "\n");

	std.file.write(dic, csv);
}

wstring guessWord(wstring word)
{
	struct Tr { wstring match, replace; }
	immutable Tr startsWith[] =
	[
		{ "awe", "å" },
		{ "ab", "äb" },
		{ "ac", "äc" },
		{ "ad", "äd" },
		{ "ag", "äg" },
		{ "ad", "äd" },
		{ "an", "än" },
		{ "ap", "äp" },
		{ "at", "ät" },
		{ "av", "äv" },
		{ "x", "z" },
	];
	immutable Tr endsWith[] =
	[
		{ "re", "r" },
		{ "ise", "īz" },
		{ "ize", "īz" },
		{ "able", "äbl" },
		{ "tion", "šn" },
		{ "tion", "šn" },
		{ "y", "ē" },
		{ "ge", "ž" },
	];
	immutable Tr contains[] =
	[
		{ "ore", "år" },
		{ "ire", "īr" },
		{ "ge", "je" },

		{ "and", "änd" },
		{ "ant", "änt" },
		{ "ang", "äŋ" },
		{ "at", "ät" },

		{ "theo", "þio" },
		{ "there", "ðer" },
		{ "them", "ðem" },
		{ "ther", "þer" },
		{ "th", "þ" },
		{ "tio", "šo" },
		{ "ph", "f" },
		{ "qu", "ku" },
		{ "igh", "ī" },
		{ "ought", "ååt" },
		{ "ee", "ē" },
		{ "ook", "uk" },
		{ "oo", "üü" },
		{ "oi", "åi" },
		{ "ain", "ān" },
		{ "er", "ǝr" },
		{ "ogi", "ojē" },
		{ "ogy", "ojē" },
		{ "bush", "buš" },
		{ "cush", "kuš" },
		{ "push", "puš" },
		{ "ush", "aš" },

		{ "cce", "ks" },
		{ "cc", "kk" },
		{ "ces", "ses" },
		{ "ce", "s" },
		{ "ch", "č" },
		{ "ci", "si" },
		{ "ck", "k" },
		{ "cy", "sī" },
		{ "c", "k" },
		{ "x", "ks" },
		{ "sh", "š" },
		{ "ssio", "š" },
		{ "sio", "ž" },
		{ "ng", "ŋ" },
	];

	wstring w = word;

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

DicWord* findWord(const wchar[] word, DicWord[] dictionary)
{
	foreach(ref w; dictionary)
	{
		if(!icmp(word, w.eng))
			return &w;
	}

	return null;
}
