#import "NSString+WMFHTMLParsing.h"
#import "WikipediaAppUtils.h"
#import <hpple/TFHpple.h>
#import "NSString+Extras.h"

@implementation NSString (WMFHTMLParsing)

- (NSArray*)wmf_htmlTextNodes {
    return [[[[TFHpple alloc]
              initWithHTMLData:[self dataUsingEncoding:NSUTF8StringEncoding]]
             searchWithXPathQuery:@"//text()"]
            valueForKey:WMF_SAFE_KEYPATH([TFHppleElement new], content)];
}

- (NSString*)wmf_getCollapsedWhitespaceStringAdjustedForTerminalPunctuation {
    NSString* result = [self wmf_stringByCollapsingAllWhitespaceToSingleSpaces];
    result = [result wmf_stringByRemovingWhiteSpaceBeforeCommasAndSemicolons];
    result = [result wmf_stringByRemovingWhiteSpaceBeforePeriod];
    result = [result stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    return result;
}

- (NSString*)wmf_joinedHtmlTextNodes {
    return [self wmf_joinedHtmlTextNodesWithDelimiter:@" "];
}

- (NSString*)wmf_joinedHtmlTextNodesWithDelimiter:(NSString*)delimiter {
    return [[self wmf_htmlTextNodes] componentsJoinedByString:delimiter];
}

#pragma mark - String simplification and cleanup

- (NSString*)wmf_shareSnippetFromText {
    return [[[[[[[[[[self stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"]
                    stringByReplacingOccurrencesOfString:@"&gt;" withString:@">"]
                   stringByReplacingOccurrencesOfString:@"&lt;" withString:@"<"]
                  wmf_stringByCollapsingConsecutiveNewlines]
                 wmf_stringByRecursivelyRemovingParenthesizedContent]
                wmf_stringByRemovingBracketedContent]
               wmf_stringByRemovingWhiteSpaceBeforeCommasAndSemicolons]
              wmf_stringByRemovingWhiteSpaceBeforePeriod]
             wmf_stringByCollapsingConsecutiveSpaces]
            wmf_stringByRemovingLeadingOrTrailingSpacesNewlinesOrColons];
}

- (NSString*)wmf_stringByCollapsingConsecutiveNewlines {
    NSParameterAssert([NSThread isMainThread]);
    static NSRegularExpression* newlinesRegex;
    if (!newlinesRegex) {
        newlinesRegex = [NSRegularExpression regularExpressionWithPattern:@"\n{2,}"
                                                                  options:0
                                                                    error:nil];
    }
    return [newlinesRegex stringByReplacingMatchesInString:self
                                                   options:0
                                                     range:NSMakeRange(0, self.length)
                                              withTemplate:@"\n"];
}

- (NSString*)wmf_stringByRecursivelyRemovingParenthesizedContent {
    // We probably don't want to handle ideographic parens
    static NSRegularExpression* parensRegex;
    if (!parensRegex) {
        parensRegex = [NSRegularExpression
                       regularExpressionWithPattern:@"[(][^()]+[)]"
                                            options:0
                                              error:nil];
    }

    NSString* string = [self copy];
    NSString* oldResult;
    NSRange range;
    do {
        oldResult = [string copy];
        range     = NSMakeRange(0, string.length);
        string    = [parensRegex stringByReplacingMatchesInString:string
                                                          options:0
                                                            range:range
                                                     withTemplate:@""];
    } while (![oldResult isEqualToString:string]);
    return string;
}

- (NSString*)wmf_stringByRemovingBracketedContent {
    // We don't care about ideographic brackets
    // Nested bracketing unseen thus far
    static NSRegularExpression* bracketedRegex;
    if (!bracketedRegex) {
        bracketedRegex = [NSRegularExpression
                          regularExpressionWithPattern:@"\\[[^]]+]"
                                               options:0
                                                 error:nil];
    }
    return [bracketedRegex stringByReplacingMatchesInString:self
                                                    options:0
                                                      range:NSMakeRange(0, self.length)
                                               withTemplate:@""];
}

- (NSString*)wmf_stringByRemovingWhiteSpaceBeforeCommasAndSemicolons {
    // Unlike parens and brackets and unlike doubled up space in general,
    // we do not want whitespace preceding the comma, ideographic comma,
    // or semicolon
    static NSRegularExpression* spaceCommaColonRegex;
    if (!spaceCommaColonRegex) {
        spaceCommaColonRegex = [NSRegularExpression
                                regularExpressionWithPattern:@"\\s+([,、;])"
                                                     options:0
                                                       error:nil];
    }
    return [spaceCommaColonRegex stringByReplacingMatchesInString:self
                                                          options:0
                                                            range:NSMakeRange(0, self.length)
                                                     withTemplate:@"$1"];
}

- (NSString*)wmf_stringByRemovingWhiteSpaceBeforePeriod {
    // Ideographic stops from TextExtracts, which were from OpenSearch
    static NSRegularExpression* spacePeriodRegex;
    if (!spacePeriodRegex) {
        spacePeriodRegex = [NSRegularExpression
                            regularExpressionWithPattern:@"\\s+([\\.|。|．|｡])"
                                                 options:0
                                                   error:nil];
    }
    return [spacePeriodRegex stringByReplacingMatchesInString:self
                                                      options:0
                                                        range:NSMakeRange(0, self.length)
                                                 withTemplate:@"$1"];
}

- (NSString*)wmf_stringByCollapsingConsecutiveSpaces {
    // In practice, we rarely care about doubled up whitespace in the
    // string except for the actual space character
    static NSRegularExpression* spacesRegex;
    if (!spacesRegex) {
        spacesRegex = [NSRegularExpression
                       regularExpressionWithPattern:@" {2,}"
                                            options:0
                                              error:nil];
    }
    return [spacesRegex stringByReplacingMatchesInString:self
                                                 options:0
                                                   range:NSMakeRange(0, self.length)
                                            withTemplate:@" "];
}

- (NSString*)wmf_stringByCollapsingAllWhitespaceToSingleSpaces {
    static NSRegularExpression* whitespaceRegex;
    if (!whitespaceRegex) {
        whitespaceRegex = [NSRegularExpression
                           regularExpressionWithPattern:@"\\s+"
                                                options:0
                                                  error:nil];
    }
    return [whitespaceRegex stringByReplacingMatchesInString:self
                                                     options:0
                                                       range:NSMakeRange(0, self.length)
                                                withTemplate:@" "];
}

- (NSString*)wmf_stringByRemovingLeadingOrTrailingSpacesNewlinesOrColons {
    // Note about trailing colon characters: they usually look strange if kept,
    // and removing them (plus spaces and newlines) doesn't often create merged
    // words that look bad - these are usually at tag boundaries. For Latinized
    // langs sometimes this means words like "include" finish the snippet.
    // But as a matter of markup structure, something like a <p> tag
    // shouldn't be </p> closed until something like <ul>...</ul> is closed.
    // In fact, some sections have this layout, and some do not.
    static NSRegularExpression* leadTrailColonRegex;
    if (!leadTrailColonRegex) {
        leadTrailColonRegex = [NSRegularExpression
                               regularExpressionWithPattern:@"^[\\s\n]+|[\\s\n:]+$"
                                                    options:0
                                                      error:nil];
    }
    return [leadTrailColonRegex stringByReplacingMatchesInString:self
                                                         options:0
                                                           range:NSMakeRange(0, self.length)
                                                    withTemplate:@""];
}

@end
