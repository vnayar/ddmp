/*
 * Copyright 2008 Google Inc. All Rights Reserved.
 * Copyright 2013-2014 Jan Krüger. All Rights Reserved.
 * Author: fraser@google.com (Neil Fraser)
 * Author: anteru@developer.shelter13.net (Matthaeus G. Chajdas)
 * Author: jan@jandoe.de (Jan Krüger)
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Diff Match and Patch
 * http://code.google.com/p/google-diff-match-patch/
 */
module ddmp.patch;
import std.array;
import std.conv;
import std.string:lastIndexOf;

import ddmp.diff;
import ddmp.match;
import ddmp.util;

int MATCH_MAXBITS = 32;
int PATCH_MARGIN = 4;
float PATCH_DELETE_THRESHOLD = 0.5f;

struct Patch {
    Diff[] diffs;
    sizediff_t start1;
    sizediff_t start2;
    sizediff_t length1;
    sizediff_t length2;

    string toString()
    const {
    	import std.uri : encode;

        auto app = appender!string();
        app.put("@@ -");
        if( length1 == 0 ){
            app.put(to!string(start1));
            app.put(",0");
        } else if( length1 == 1 ){
            app.put(to!string(start1 + 1));
        } else {
            app.put(to!string(start1 + 1));
            app.put(",");
            app.put(to!string(length1));
        }
        app.put(" +");
        if( length2 == 0 ){
            app.put(to!string(start2));
            app.put(",0");
        } else if( length2 == 1 ){
            app.put(to!string(start2 + 1));
        } else {
            app.put(to!string(start2 + 1));
            app.put(",");
            app.put(to!string(length2));
        }
        app.put(" @@\n");
        foreach( d ; diffs){
            final switch( d.operation ){
                case Operation.INSERT:
                    app.put("+");
                    break;
                case Operation.DELETE:
                    app.put("-");
                    break;
                case Operation.EQUAL:
                    app.put(" ");
                    break;
            }
            app.put(encode(d.text).replace("%20", " "));
            app.put("\n");
        }

        return unescapeForEncodeUriCompatibility(app.data());
    }
}

/**
 * Increase the context until it is unique,
 * but don't let the pattern expand beyond Match_MaxBits.
 * @param patch The patch to grow.
 * @param text Source text.
 */
void addContext(Patch patch, string text)
{
	if( text.length == 0 ) return;

	auto pattern = text.substr(patch.start2, patch.length1);
	sizediff_t padding = 0;

	// Look for the first and last matches of pattern in text.  If two
	// different matches are found, increase the pattern length.
	while( text.indexOfAlt(pattern) != text.lastIndexOf(pattern)
		  && pattern.length < MATCH_MAXBITS - PATCH_MARGIN - PATCH_MARGIN ){
		padding += PATCH_MARGIN;
		pattern = text[max(0, patch.start2 - padding)..min(text.length, patch .start2 + patch.length1 + padding)];		
	}
	// Add one chunk for good luck.
	padding += PATCH_MARGIN;

	// Add the prefix.
	auto prefix = text[max(0, patch.start2 - padding)..patch.start2];
	if( prefix.length != 0 ){
		patch.diffs.insert(0, [Diff(Operation.EQUAL, prefix)]);
	}

	// Add the suffix.
	auto suffix = text[patch.start2 + patch.length1..min(text.length, patch.start2 + patch.length1 + padding)];
	if( suffix.length != 0 ){
		patch.diffs ~= Diff(Operation.EQUAL, suffix);
	}

	// Roll back the start points.
	patch.start1 -= prefix.length;
	patch.start2 -= prefix.length;
	// Extend the lengths.
	patch.length1 += prefix.length + suffix.length;
	patch.length2 += prefix.length + suffix.length;
}

/**
* Compute a list of patches to turn text1 into text2.
* A set of diffs will be computed.
* @param text1 Old text.
* @param text2 New text.
* @return List of Patch objects.
*/
Patch[] patch_make(string text1, string text2) {
	// No diffs provided, comAdde our own.
	auto diffs = diff_main(text1, text2, true);
	if (diffs.length > 2) {
		cleanupSemantic(diffs);
		cleanupEfficiency(diffs);
	}
	return patch_make(text1, diffs);
}


/**
 * Compute a list of patches to turn text1 into text2.
 * text1 will be derived from the provided diffs.
 * @param diffs Array of Diff objects for text1 to text2.
 * @return List of Patch objects.
 */
Patch[] patch_make(Diff[] diffs) {
  // Check for null inputs not needed since null can't be passed in C#.
  // No origin string provided, comAdde our own.
  auto text1 = diff_text1(diffs);
  return patch_make(text1, diffs);
}


/**
 * Compute a list of patches to turn text1 into text2.
 * text2 is not provided, diffs are the delta between text1 and text2.
 * @param text1 Old text.
 * @param diffs Array of Diff objects for text1 to text2.
 * @return List of Patch objects.
 */
Patch[] patch_make(string text1, Diff[] diffs)
{
	Patch[] patches;
	if( diffs.length == 0 ) return patches;
	
	Patch patch;
	auto char_count1 = 0;  // Number of characters into the text1 string.
	auto char_count2 = 0;  // Number of characters into the text2 string.
	// Start with text1 (prepatch_text) and apply the diffs until we arrive at
	// text2 (postpatch_text). We recreate the patches one by one to determine
	// context info.
	auto prepatch_text = text1;
	auto postpatch_text = text1;

	foreach( diff ; diffs ){
		if( patch.diffs.length == 0 && diff.operation != Operation.EQUAL ){
			// A new patch starts here.
			patch.start1 = char_count1;
			patch.start2 = char_count2;
		}

		final switch(diff.operation){
			case Operation.INSERT:
				patch.diffs ~= diff;
				patch.length2 += diff.text.length;
				postpatch_text.insert(char_count2, diff.text);
				break;
			case Operation.DELETE:
				patch.length2 += diff.text.length;
				patch.diffs ~= diff;
				postpatch_text.remove(char_count2, diff.text.length);
				break;
			case Operation.EQUAL:
				if( diff.text.length <= 2 * PATCH_MARGIN && patch.diffs.length != 0 && diff != diffs[$-1] ){
					patch.diffs ~= diff;
					patch.length1 += diff.text.length;
					patch.length2 += diff.text.length;
				}

				if( diff.text.length >= 2 * PATCH_MARGIN ){
					if( patch.diffs.length != 0 ){
						addContext(patch, prepatch_text);
						patches ~= patch;
						patch = Patch();
						prepatch_text = postpatch_text;
						char_count1 = char_count2;
					}
				}
				break;
		}
        // Update the current character count.
        if (diff.operation != Operation.INSERT) {
          char_count1 += diff.text.length;
        }
        if (diff.operation != Operation.DELETE) {
          char_count2 += diff.text.length;
        }
    }
	// Pick up the leftover patch if not empty.
    if( !patch.diffs.empty ){
    	addContext(patch, prepatch_text);
    	patches ~= patch;
    }

    return patches;
}


/**
 * Merge a set of patches onto the text.  Return a patched text, as well
 * as an array of true/false values indicating which patches were applied.
 * @param patches Array of Patch objects
 * @param text Old text.
 * @return Two element Object array, containing the new text and an array of
 *      bool values.
 */

 struct PatchApplyResult {
 	string text;
 	bool[] patchesApplied;
 }

 PatchApplyResult apply(Patch[] patches, string text) 
 {
 	PatchApplyResult result;
 	if( patches.length == 0 ) return result;
 
 	auto nullPadding = addPadding(patches);
 	text = nullPadding ~ text ~ nullPadding;
 	splitMax(patches);

 	result.patchesApplied.length = patches.length; // init patchesApplied array
 	sizediff_t x = 0;
	// delta keeps track of the offset between the expected and actual
	// location of the previous patch.  If there are patches expected at
	// positions 10 and 20, but the first patch was found at 12, delta is 2
	// and the second patch has an effective expected position of 22.
	sizediff_t delta = 0; 	
	foreach( patch ; patches ){
		auto expected_loc = patch.start2 + delta;
		auto text1 =  diff_text1(patch.diffs);
		sizediff_t start_loc;
		sizediff_t end_loc = -1;
		if( text1.length > MATCH_MAXBITS ){
			// patch_splitMax will only provide an oversized pattern
         	// in the case of a monster delete
         	start_loc = match_main(text, text1.substr(0, MATCH_MAXBITS), expected_loc);
         	if( start_loc != -1 ){
         		end_loc = match_main(text,
         			text1.substr(text1.length - MATCH_MAXBITS),
         			expected_loc + text1.length - MATCH_MAXBITS);
         		if( end_loc == -1 || start_loc >= end_loc ){
         			// Can't find valid trailing context.  Drop this patch.
         			start_loc = -1;
         		}
         	}
		} else {
			start_loc = match_main(text, text1, expected_loc);
		}
		if( start_loc == -1 ){
			// No match found.  :(
			result.patchesApplied[x] = false;
			// Subtract the delta for this failed patch from subsequent patches.
			delta -= patch.length2 - patch.length1;
		} else {
			// Found a match. :)
			result.patchesApplied[x] = true;
			delta = start_loc - expected_loc;
			string text2;
			if( end_loc == -1 ){
				text2 = text[ start_loc .. min(start_loc + text1.length, text.length) ];
			} else {
				text2 = text[ start_loc .. min(end_loc + MATCH_MAXBITS, text.length) ];
			}
			if( text1 == text2 ) {
				// Perfect match, just shove the replacement text in.
				text = text.substr(0, start_loc) ~ diff_text2(patch.diffs) ~ text.substr(start_loc + text1.length);			
			} else {
				// Imperfect match. Run a diff to get a framework of equivalent indices.
				auto diffs = diff_main(text1, text2, false);
				if( text1.length > MATCH_MAXBITS && levenshtein(diffs) / cast(float)text1.length > PATCH_DELETE_THRESHOLD){
					// The end points match, but the content is unacceptably bad.
					result.patchesApplied[x] = false;
				} else {
					cleanupSemanticLossless(diffs);
					auto index1 = 0;
					foreach( diff; patch.diffs ){
						if( diff.operation != Operation.EQUAL ){
							auto index2 = xIndex(diffs, index1);
							if( diff.operation == Operation.INSERT ){
								// Insertion
								text.insert(start_loc + index2, diff.text);
							} else if( diff.operation == Operation.DELETE ){
								// Deletion
								text.remove(start_loc + index2, xIndex(diffs, index1 + diff.text.length) - index2);
							}
						}
						if( diff.operation != Operation.DELETE ){
							index1 += diff.text.length;
						}
					}
				}
			}
		}
		x++;
	} 
	// Strip the padding off.
	result.text = text.substr(nullPadding.length, text.length - 2 * nullPadding.length);
	return result;
}

/**
 * Add some padding on text start and end so that edges can match something.
 * Intended to be called only from within patch_apply.
 * @param patches Array of Patch objects.
 * @return The padding string added to each side.
 */
string addPadding(Patch[] patches)
{
	auto paddingLength = PATCH_MARGIN;
	string nullPadding;
	for(sizediff_t x = 1; x <= paddingLength; x++){
		nullPadding ~= cast(char)x;
	}

	// Bump all the patches forward.
	foreach( patch; patches ){
		patch.start1 += paddingLength;
		patch.start2 += paddingLength;
	}

	// Add some padding on start of first diff.
	Patch patch = patches[0];
	auto diffs = patch.diffs;
	if( diffs.length == 0 || diffs[0].operation != Operation.EQUAL ){		
		// Add nullPadding equality.
		diffs.insert(0, [Diff(Operation.EQUAL, nullPadding)]);
		patch.start1 -= paddingLength;  // Should be 0.
		patch.start2 -= paddingLength;  // Should be 0.
		patch.length1 += paddingLength;
		patch.length2 += paddingLength;
	} else if (paddingLength > diffs[0].text.length) {
		// Grow first equality.
		Diff firstDiff = diffs[0];
		auto extraLength = paddingLength - firstDiff.text.length;
		firstDiff.text = nullPadding.substr(firstDiff.text.length) ~ firstDiff.text;
		patch.start1 -= extraLength;
		patch.start2 -= extraLength;
		patch.length1 += extraLength;
		patch.length2 += extraLength;
	}

	// Add some padding on end of last diff.
	patch = patches[$-1];
	diffs = patch.diffs;
	if( diffs.length == 0 || diffs[$-1].operation != Operation.EQUAL) {
		// Add nullPadding equality.
		diffs ~= Diff(Operation.EQUAL, nullPadding);
		patch.length1 += paddingLength;
		patch.length2 += paddingLength;
	} else if (paddingLength > diffs[$-1].text.length) {
		// Grow last equality.
		Diff lastDiff = diffs[$-1];
		auto extraLength = paddingLength - lastDiff.text.length;
		lastDiff.text ~= nullPadding.substr(0, extraLength);
		patch.length1 += extraLength;
		patch.length2 += extraLength;
	}
	return nullPadding;
}

/**
 * Look through the patches and break up any which are longer than the
 * maximum limit of the match algorithm.
 * Intended to be called only from within patch_apply.
 * @param patches List of Patch objects.
 */
void splitMax(Patch[] patches)
{
	auto patch_size = MATCH_MAXBITS;
	for( auto x = 0; x < patches.length; x++ ){
		if( patches[x].length1 <= patch_size ) continue;
		Patch bigpatch = patches[x];
		patches.splice(x--, 1);
		auto start1 = bigpatch.start1;
		auto start2 = bigpatch.start2;
		string precontext;
		while( bigpatch.diffs.length != 0){
			Patch patch;
			bool empty = true;
			patch.start1 = start1 - precontext.length;
			patch.start2 = start2 - precontext.length;			
			if( precontext.length != 0 ){
				patch.length1 = patch.length2 = precontext.length;
				patch.diffs ~= Diff(Operation.EQUAL, precontext);
			}
			while( bigpatch.diffs.length != 0 && patch.length1 < patch_size - PATCH_MARGIN ){
				Operation diff_type = bigpatch.diffs[0].operation;
				auto diff_text = bigpatch.diffs[0].text;
				if( diff_type == Operation.INSERT ){
					// Insertions are harmless.
					patch.length2 += diff_text.length;
					start2 += diff_text.length;
					patch.diffs ~= bigpatch.diffs[0];
					bigpatch.diffs.remove(0);
					empty = false;
				} else if( diff_type == Operation.DELETE && patch.diffs.length == 1
					&& patch.diffs[0].operation == Operation.EQUAL
					&& diff_text.length > 2 * patch_size) {
              		// This is a large deletion.  Let it pass in one chunk.
              		patch.length1 += diff_text.length;
              		start1 += diff_text.length;
              		empty = false;
              		patch.diffs ~= Diff(diff_type, diff_text);
              		bigpatch.diffs.remove(0);
				} else {
					// Deletion or equality. Only takes as much as we can stomach.
					diff_text = diff_text.substr(0, min(diff_text.length, patch_size - patch.length1 - PATCH_MARGIN));
					patch.length1 += diff_text.length;
					start1 += diff_text.length;
					if( diff_type == Operation.EQUAL ){
						patch.length2 += diff_text.length;
						start2 += diff_text.length;
					} else {
						empty = false;
					}
					patch.diffs ~= Diff(diff_type, diff_text);
					if( diff_text == bigpatch.diffs[0].text ){
						bigpatch.diffs.remove(0);
					} else {
						bigpatch.diffs[0].text = bigpatch.diffs[0].text.substr(diff_text.length);
					}
				}
			}
			// Compute the head context for the next patch.
			precontext = diff_text2(patch.diffs);
			precontext = precontext.substr(max(0, precontext.length - PATCH_MARGIN));

			auto postcontext = diff_text1(bigpatch.diffs);
			if( postcontext.length > PATCH_MARGIN ){
				postcontext =  postcontext.substr(0, PATCH_MARGIN);
			}

			if( postcontext.length != 0 ){
				patch.length1 += postcontext.length;
				patch.length2 += postcontext.length;
				if( patch.diffs.length != 0 
					&& patch.diffs[patch.diffs.length - 1].operation
					== Operation.EQUAL) {
					patch.diffs[$].text ~= postcontext;
				} else {
					patch.diffs ~= Diff(Operation.EQUAL, postcontext);
				}
			}
			if( !empty ){
				patches.splice(++x, 0, [patch]);
			}
		}
	}
}

/**
 * Take a list of patches and return a textual representation.
 * @param patches List of Patch objects.
 * @return Text representation of patches.
 */
public string patch_toText(in Patch[] patches)
{
	auto text = appender!string();
	foreach (aPatch; patches)
		text ~= aPatch.toString();
	return text.data;
}

/**
 * Parse a textual representation of patches and return a List of Patch
 * objects.
 * @param textline Text representation of patches.
 * @return List of Patch objects.
 * @throws ArgumentException If invalid input.
 */
public Patch[] patch_fromText(string textline)
{
	import std.regex : regex, matchFirst;
	import std.string : format, split;

	auto patches = appender!(Patch[])();
	if (textline.length == 0) return null;

	auto text = textline.split("\n");
	sizediff_t textPointer = 0;
	auto patchHeader = regex("^@@ -(\\d+),?(\\d*) \\+(\\d+),?(\\d*) @@$");
	char sign;
	string line;
	while (textPointer < text.length) {
		auto m = matchFirst(text[textPointer], patchHeader);
		enforce (m, "Invalid patch string: " ~ text[textPointer]);
		Patch patch;
		patch.start1 = m[0].to!sizediff_t;
		if (m[1].length == 0) {
			patch.start1--;
			patch.length1 = 1;
		} else if (m[1] == "0") {
			patch.length1 = 0;
		} else {
			patch.start1--;
			patch.length1 = m[1].to!sizediff_t;
		}

		patch.start2 = m[2].to!sizediff_t;
		if (m[3].length == 0) {
			patch.start2--;
			patch.length2 = 1;
		} else if (m[3] == "0") {
			patch.length2 = 0;
		} else {
			patch.start2--;
			patch.length2 = m[3].to!sizediff_t;
		}
		textPointer++;

		while (textPointer < text.length) {
			import std.uri : decode;
			if (textPointer >= text.length || !text[textPointer].length) {
				// Blank line?  Whatever.
				textPointer++;
				continue;
			}
			sign = text[textPointer][0];
			line = text[textPointer][1 .. $];
			line = line.replace("+", "%2b");
			line = decode(line);
			if (sign == '-') {
				// Deletion.
				patch.diffs ~= Diff(Operation.DELETE, line);
			} else if (sign == '+') {
				// Insertion.
				patch.diffs ~= Diff(Operation.INSERT, line);
			} else if (sign == ' ') {
				// Minor equality.
				patch.diffs ~= Diff(Operation.EQUAL, line);
			} else if (sign == '@') {
				// Start of next patch.
				break;
			} else {
				// WTF?
				throw new Exception(format("Invalid patch mode '%s' in: %s", sign, line));
			}
			textPointer++;
		}

		patches ~= patch;
	}
	return patches.data;
}
