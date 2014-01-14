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
module ddmp.util;

import std.string:indexOf;

string substr(string str, int start, int len=-1) {
    auto end = len < 0 ? str.length : start + len;
    return str[start..end];
}

sizediff_t indexOfAlt(string str, string search, int offset=0) {
    auto index = str[offset..$].indexOf(search);
    if (index > -1 ) return index + offset;
    return -1;
}

void insert(T)( ref T[] array, int i, T[] stuff) 
{   
    array = array[0..i] ~ stuff ~ array[i..$];
}
void remove(T)( ref T[] array, int i, int count=1)
{
    array = array[0..i] ~ array[i+count..$];
}

T[] splice(T)(ref T[] list, int start, int count, T[] objects=null) {
    T[] deletedRange = list[start..start+count];
    list = list[0 .. start] ~ objects ~ list[start+count .. $];
    return deletedRange;
}