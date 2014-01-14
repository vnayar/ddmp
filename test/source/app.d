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
module app;

import std.stdio;
import ddmp.diff;
import ddmp.patch;
import ddmp.match;

void testDiffCommonPrefix() {
  // Detect any common prefix.
  // Null case.
  assert(0 == commonPrefix("abc", "xyz"));

  // Non-null case.
  assert(4 == commonPrefix("1234abcdef", "1234xyz"));

  // Whole case.
  assert(4 == commonPrefix("1234", "1234xyz"));
}

void testDiffCommonSuffix() {
  // Detect any common suffix.
  // Null case.
  assert(0 == commonSuffix("abc", "xyz"));

  // Non-null case.
  assert(4 == commonSuffix("abcdef1234", "xyz1234"));

  // Whole case.
  assert(4 == commonSuffix("1234", "xyz1234"));
}

void testDiffCommonOverlap() {
  // Detect any suffix/prefix overlap.
  // Null case.
  assert(0 == commonOverlap("", "abcd"));

  // Whole case.
  assert(3 == commonOverlap("abc", "abcd"));

  // No overlap.
  assert(0 == commonOverlap("123456", "abcd"));

  // Overlap.
  assert(3 == commonOverlap("123456xxx", "xxxabcd"));

  // Unicode.
  // Some overly clever languages (C#) may treat ligatures as equal to their
  // component letters.  E.g. U+FB01 == "fi"
  assert(0 == commonOverlap("fi", "\ufb01i"));
}

void testDiffHalfMatch() {
  // No match.
	{
		HalfMatch hm_cmp, hm;
		assert(!halfMatch("1234567890", "abcdef", hm_cmp));
	}

	{
		HalfMatch hm_cmp, hm;
		assert(!halfMatch("12345", "23", hm_cmp));
	}
  // Single Match.
	{
		HalfMatch hm_cmp, hm;
		hm.prefix1 = "12"; hm.suffix1 = "90"; hm.prefix2 ="a"; hm.suffix2 = "z"; hm.commonMiddle = "345678";
		halfMatch("1234567890", "a345678z", hm_cmp);
		assert(hm == hm_cmp);
	}
  {
    HalfMatch hm_cmp, hm;
    hm.prefix1 = "a"; hm.suffix1 = "z"; hm.prefix2 ="12"; hm.suffix2 = "90"; hm.commonMiddle = "345678";
    halfMatch("a345678z", "1234567890", hm_cmp);
    assert(hm == hm_cmp);
  }
	{
		HalfMatch hm_cmp, hm;
		hm.prefix1 = "abc"; hm.suffix1 = "z"; hm.prefix2 ="1234"; hm.suffix2 = "0"; hm.commonMiddle = "56789";
		assert(halfMatch("abc56789z", "1234567890", hm_cmp));
		assert(hm == hm_cmp);		
	}

	{
		HalfMatch hm_cmp, hm;
		hm.prefix1 = "a"; hm.suffix1 = "xyz"; hm.prefix2 ="1"; hm.suffix2 = "7890"; hm.commonMiddle = "23456";
		assert(halfMatch("a23456xyz", "1234567890", hm_cmp));
		assert(hm == hm_cmp);		
	}

  // Multiple Matches.
  {
    HalfMatch hm_cmp, hm;
    hm.prefix1 = "12123"; hm.suffix1 = "123121"; hm.prefix2 ="a"; hm.suffix2 = "z"; hm.commonMiddle = "1234123451234";
    assert(halfMatch("121231234123451234123121", "a1234123451234z", hm_cmp));
    assert(hm == hm_cmp);   
  }

  {
    HalfMatch hm_cmp, hm;
    hm.prefix1 = ""; hm.suffix1 = "-=-=-=-=-="; hm.prefix2 ="x"; hm.suffix2 = ""; hm.commonMiddle = "x-=-=-=-=-=-=-=";
    assert(halfMatch("x-=-=-=-=-=-=-=-=-=-=-=-=", "xx-=-=-=-=-=-=-=", hm_cmp));
    assert(hm == hm_cmp);   
  }

  {
    HalfMatch hm_cmp, hm;
    hm.prefix1 = "-=-=-=-=-="; hm.suffix1 = ""; hm.prefix2 = ""; hm.suffix2 = "y"; hm.commonMiddle = "-=-=-=-=-=-=-=y";
    assert(halfMatch("-=-=-=-=-=-=-=-=-=-=-=-=y", "-=-=-=-=-=-=-=yy", hm_cmp));
    assert(hm == hm_cmp);   
  }
}

void testDiffLinesToChars() {
  {
    LinesToCharsResult result;
    result.text1 = "\x01\x02\x01";
    result.text2 = "\x02\x01\x02";
    result.uniqueStrings = ["", "alpha\n", "beta\n"];
    assert(result == linesToChars("alpha\nbeta\nalpha\n", "beta\nalpha\nbeta\n"));
  }
  {
    LinesToCharsResult result;
    result.text1 = "";
    result.text2 = "\x01\x02\x03\x03";
    result.uniqueStrings = ["", "alpha\r\n", "beta\r\n", "\r\n"];
    assert(result == linesToChars("", "alpha\r\nbeta\r\n\r\n\r\n"));
  }
  {
    LinesToCharsResult result;
    result.text1 = "\x01";
    result.text2 = "\x02";
    result.uniqueStrings = ["", "a", "b"];
    assert(result == linesToChars("a", "b"));
  }
}

void testDiffCleanupMerge() {
  {
    //Null case
    Diff[] diffs = [];
    cleanupMerge(diffs);
    assert([] == diffs);
  }
  {
    // No change case.
    Diff[] diffs = [Diff(Operation.EQUAL, "a"), Diff(Operation.DELETE, "b"), Diff(Operation.INSERT, "c")];
    cleanupMerge(diffs);
    assert([Diff(Operation.EQUAL, "a"), Diff(Operation.DELETE, "b"), Diff(Operation.INSERT, "c")] == diffs);
  }

  {
    // Merge equalities.
    Diff[] diffs = [Diff(Operation.EQUAL, "a"), Diff(Operation.EQUAL, "b"), Diff(Operation.EQUAL, "c")];
    cleanupMerge(diffs);
    assert([Diff(Operation.EQUAL, "abc")] == diffs);
  }
  {
    // Merge deletions.
    Diff[] diffs = [Diff(Operation.DELETE, "a"), Diff(Operation.DELETE, "b"), Diff(Operation.DELETE, "c")];
    cleanupMerge(diffs);
    assert([Diff(Operation.DELETE, "abc")] == diffs);
  }
  {
    // Merge insertions.
    Diff[] diffs = [Diff(Operation.INSERT, "a"), Diff(Operation.INSERT, "b"), Diff(Operation.INSERT, "c")];
    cleanupMerge(diffs);
    assert([Diff(Operation.INSERT, "abc")] == diffs);
  }
  {
    // Merge interweave.
    Diff[] diffs = [Diff(Operation.DELETE, "a"), Diff(Operation.INSERT, "b"), Diff(Operation.DELETE, "c"), Diff(Operation.INSERT, "d"), Diff(Operation.EQUAL, "e"), Diff(Operation.EQUAL, "f")];
    cleanupMerge(diffs);
    assert([Diff(Operation.DELETE, "ac"), Diff(Operation.INSERT, "bd"), Diff(Operation.EQUAL, "ef")] == diffs);
  }
  {
    // Prefix and suffix detection.
    Diff[] diffs = [Diff(Operation.DELETE, "a"), Diff(Operation.INSERT, "abc"), Diff(Operation.DELETE, "dc")];
    cleanupMerge(diffs);
    assert([Diff(Operation.EQUAL, "a"), Diff(Operation.DELETE, "d"), Diff(Operation.INSERT, "b"), Diff(Operation.EQUAL, "c")] == diffs);
  }
  {
    // Prefix and suffix detection with equalities.
    Diff[] diffs = [Diff(Operation.EQUAL, "x"), Diff(Operation.DELETE, "a"), Diff(Operation.INSERT, "abc"), Diff(Operation.DELETE, "dc"), Diff(Operation.EQUAL, "y")];
    cleanupMerge(diffs);
    assert([Diff(Operation.EQUAL, "xa"), Diff(Operation.DELETE, "d"), Diff(Operation.INSERT, "b"), Diff(Operation.EQUAL, "cy")] == diffs);
  }
  {
    // Slide edit left.
    Diff[] diffs = [Diff(Operation.EQUAL, "a"), Diff(Operation.INSERT, "ba"), Diff(Operation.EQUAL, "c")];
    cleanupMerge(diffs);
    assert([Diff(Operation.INSERT, "ab"), Diff(Operation.EQUAL, "ac")] == diffs);
  }
  {
    // Slide edit right.
    Diff[] diffs = [Diff(Operation.EQUAL, "c"), Diff(Operation.INSERT, "ab"), Diff(Operation.EQUAL, "a")];
    cleanupMerge(diffs);
    assert([Diff(Operation.EQUAL, "ca"), Diff(Operation.INSERT, "ba")] == diffs);
  }
    {
    // Slide edit left recursive.
    Diff[] diffs = [Diff(Operation.EQUAL, "a"), Diff(Operation.DELETE, "b"), Diff(Operation.EQUAL, "c"), Diff(Operation.DELETE, "ac"), Diff(Operation.EQUAL, "x")];
    cleanupMerge(diffs);
    assert([Diff(Operation.DELETE, "abc"), Diff(Operation.EQUAL, "acx")] == diffs);
  }
  {
    // Slide edit right recursive.
    Diff[] diffs = [Diff(Operation.EQUAL, "x"), Diff(Operation.DELETE, "ca"), Diff(Operation.EQUAL, "c"), Diff(Operation.DELETE, "b"), Diff(Operation.EQUAL, "a")];
    cleanupMerge(diffs);
    assert([Diff(Operation.EQUAL, "xca"), Diff(Operation.DELETE, "cba")] == diffs);
  }
}


void testDiffCleanupSemanticLossless() {
  // Slide diffs to match logical boundaries.
  {  
    // Null case.
    Diff[] diffs = [];
    cleanupSemanticLossless(diffs);
    assert([] == diffs);
  } 
  /*{
    // Blank lines.
    Diff[] diffs = [Diff(Operation.EQUAL, "AAA\r\n\r\nBBB"), Diff(Operation.INSERT, "\r\nDDD\r\n\r\nBBB"), Diff(Operation.EQUAL, "\r\nEEE")];
    assert([Diff(Operation.EQUAL, "AAA\r\n\r\n"), Diff(Operation.INSERT, "BBB\r\nDDD\r\n\r\n"), Diff(Operation.EQUAL, "BBB\r\nEEE")] == diffs);
  }
  */
  {
    // Line boundaries.
    Diff[] diffs = [Diff(Operation.EQUAL, "AAA\r\nBBB"), Diff(Operation.INSERT, " DDD\r\nBBB"), Diff(Operation.EQUAL, " EEE")];
    cleanupSemanticLossless(diffs);
    assert([Diff(Operation.EQUAL, "AAA\r\n"), Diff(Operation.INSERT, "BBB DDD\r\n"), Diff(Operation.EQUAL, "BBB EEE")] == diffs);
  }
  {
    // Word boundaries.
    Diff[] diffs = [Diff(Operation.EQUAL, "The c"), Diff(Operation.INSERT, "ow and the c"), Diff(Operation.EQUAL, "at.")];
    cleanupSemanticLossless(diffs);
    assert([Diff(Operation.EQUAL, "The "), Diff(Operation.INSERT, "cow and the "), Diff(Operation.EQUAL, "cat.")] == diffs);
  }
  {
    // Alphanumeric boundaries.
    Diff[] diffs = [Diff(Operation.EQUAL, "The-c"), Diff(Operation.INSERT, "ow-and-the-c"), Diff(Operation.EQUAL, "at.")];
    cleanupSemanticLossless(diffs);
    assert([Diff(Operation.EQUAL, "The-"), Diff(Operation.INSERT, "cow-and-the-"), Diff(Operation.EQUAL, "cat.")] == diffs);
  }
  {
    // Hitting the start.
    Diff[] diffs = [Diff(Operation.EQUAL, "a"), Diff(Operation.DELETE, "a"), Diff(Operation.EQUAL, "ax")];
    writeln(diffs);
    writeln("################");
    cleanupSemanticLossless(diffs);
    writeln(diffs);
    assert([Diff(Operation.DELETE, "a"), Diff(Operation.EQUAL, "aax")] == diffs);
  }
  {
    // Hitting the end.
    Diff[] diffs = [Diff(Operation.EQUAL, "xa"), Diff(Operation.DELETE, "a"), Diff(Operation.EQUAL, "a")];
    cleanupSemanticLossless(diffs);
    assert([Diff(Operation.EQUAL, "xaa"), Diff(Operation.DELETE, "a")] == diffs);
  }
  {
    // Sentence boundaries.
    Diff[] diffs = [Diff(Operation.EQUAL, "The xxx. The "), Diff(Operation.INSERT, "zzz. The "), Diff(Operation.EQUAL, "yyy.")];
    cleanupSemanticLossless(diffs);
    assert([Diff(Operation.EQUAL, "The xxx."), Diff(Operation.INSERT, " The zzz."), Diff(Operation.EQUAL, " The yyy.")] == diffs);
  }
}



void main()
{
	testDiffCommonPrefix();
	testDiffCommonSuffix();
	testDiffCommonOverlap();
	testDiffHalfMatch();
  testDiffLinesToChars();
  testDiffCleanupMerge();
  testDiffCleanupSemanticLossless();
	writeln("All test passed");
}
