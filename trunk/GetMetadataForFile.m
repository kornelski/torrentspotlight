#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h> 
#import <Foundation/Foundation.h>
#import "BEncoding.h"

/* -----------------------------------------------------------------------------
   Step 1
   Set the UTI types the importer supports
  
   Modify the CFBundleDocumentTypes entry in Info.plist to contain
   an array of Uniform Type Identifiers (UTI) for the LSItemContentTypes 
   that your importer can handle
  
   ----------------------------------------------------------------------------- */

/* -----------------------------------------------------------------------------
   Step 2 
   Implement the GetMetadataForURL function
  
   Implement the GetMetadataForURL function below to scrape the relevant
   metadata from your document and return it as a CFDictionary using standard keys
   (defined in MDItem.h) whenever possible.
   ----------------------------------------------------------------------------- */

/* -----------------------------------------------------------------------------
   Step 3 (optional) 
   If you have defined new attributes, update schema.xml and schema.strings files
   
   The schema.xml should be added whenever you need attributes displayed in 
   Finder's get info panel, or when you have custom attributes.  
   The schema.strings should be added whenever you have custom attributes. 
 
   Edit the schema.xml file to include the metadata keys that your importer returns.
   Add them to the <allattrs> and <displayattrs> elements.
  
   Add any custom types that your importer requires to the <attributes> element
  
   <attribute name="com_mycompany_metadatakey" type="CFString" multivalued="true"/>
  
   ----------------------------------------------------------------------------- */



/* -----------------------------------------------------------------------------
    Get metadata attributes from file
   
   This function's job is to extract useful information your file format supports
   and return it as a dictionary
   ----------------------------------------------------------------------------- */

static NSString* toString(NSData *data)
{    
    if ([data isKindOfClass:[NSData class]]) 
    {
        NSString *str = [[NSString alloc] initWithBytes:(void *)[data bytes] 
                                                       length:[data length] 
                                                     encoding:NSUTF8StringEncoding];

        if (!str) str = [[NSString alloc] initWithBytes:(void *)[data bytes] 
                                                       length:[data length] 
                                                     encoding:NSWindowsCP1252StringEncoding];
        
        if (str) return [str autorelease];
    }
    if ([data isKindOfClass:[NSString class]])
    {
        return (NSString*)data;
    }

    return nil;
}

extern Boolean GetMetadataForURL(void* thisInterface, 
			   CFMutableDictionaryRef attributes, 
			   CFStringRef contentTypeUTI,
			   CFURLRef urlForFile)
{
    /* Pull any available metadata from the file at the specified path */
    /* Return the attribute keys and attribute values in the dict */
    /* Return TRUE if successful, FALSE if there was no data provided */
    
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    @try
    {
        NSDictionary *torr = [BEncoding objectFromEncodedData:[NSData dataWithContentsOfURL:(NSURL*)urlForFile]];
        if (torr)
        {            
            NSMutableDictionary *attrs = (NSMutableDictionary*)attributes;
            
            NSMutableString *comments = [NSMutableString stringWithCapacity:65000];
            
            NSString *tmp;
            if (tmp = toString([torr objectForKey:@"comment"])) {
                [comments appendString:tmp];
                [comments appendString:@"\n"];
            }
                        
            if (tmp = toString([torr objectForKey:@"created by"])) {
                [attrs setObject:tmp forKey:(NSString*)kMDItemCreator];
            }
            
            if (tmp = toString([torr objectForKey:@"submitter"])) {
                [attrs setObject:[NSArray arrayWithObject:tmp] forKey:(NSString*)kMDItemAuthors];
            }            
            
            NSNumber *tmpnum;
            if ((tmpnum = [torr objectForKey:@"creation date"]) && [tmpnum isKindOfClass:[NSNumber class]]) {
                [attrs setObject:[NSDate dateWithTimeIntervalSince1970:[tmpnum doubleValue]] forKey:(NSString*)kMDItemContentCreationDate];
            }
            
            // not quite
            if (tmp = toString([torr objectForKey:@"announce"])) {
                [attrs setObject:tmp forKey:(NSString*)kMDItemURL];
            }
            
            NSDictionary *infodict = [torr objectForKey:@"info"];
            if ([infodict isKindOfClass:[NSDictionary class]]) {
                
                // FIXME: compute info_hash
                
                if (tmp = toString([infodict objectForKey:@"name"])) {
                    [attrs setObject:tmp forKey:(NSString*)kMDItemTitle];
                }
            
                // that's a bit of a stretch
                if ((tmpnum = [infodict objectForKey:@"piece length"]) && [tmpnum isKindOfClass:[NSNumber class]]) {
                    NSUInteger bps = [tmpnum unsignedIntegerValue] * 8;
                    
                    [attrs setObject:[NSNumber numberWithUnsignedInteger:bps] forKey:(NSString*)kMDItemTotalBitRate];
                }
                
                if (tmp = toString([infodict objectForKey:@"comment"])) {
                    [comments appendString:tmp];
                    [comments appendString:@"\n"];
                }
                
                NSArray *files = [infodict objectForKey:@"files"];
                
                if (files && [files isKindOfClass:[NSArray class]]) {
                    NSMutableString *desc = [NSMutableString stringWithCapacity:65000];
                    
                    for(NSDictionary *file in files) {
                        if (![file isKindOfClass:[NSDictionary class]]) continue;
                        
                        NSArray *path = [file objectForKey:@"path"]; 
                        if (![path isKindOfClass:[NSArray class]]) continue;
                        
                        NSNumber *length = [file objectForKey:@"length"];
                        if ([length isKindOfClass:[NSNumber class]]) {
                            [desc appendFormat:@"%llu\t",[length unsignedLongLongValue]]; 
                        }
                        
                        for(NSData *path_segment in path) {
                            if (tmp = toString(path_segment)) [desc appendString:tmp];
                        }
                        [desc appendString:@"\n"];
                        
                        if (tmp = toString([file objectForKey:@"comment"])) {
                            [comments appendString:tmp];
                            [comments appendString:@"\n"];
                        }                        
                    }             
                    if ([desc length] > 1) {                
                        [attrs setObject:desc forKey:(NSString*)kMDItemDescription];
                    }                    
                }                     
                                
                if ([comments length] > 1) {                
                    [attrs setObject:comments forKey:(NSString*)kMDItemComment];
                }
                
                [attrs setObject:@"BitTorrent" forKey:(NSString*)kMDItemDeliveryType];                                
                return TRUE;                
            }
        }
    }
    @catch(NSException *e)
    {
        NSLog(@"Error during torrent import: %@",e);
    }
    NSLog(@"Torrent import failed: %@", urlForFile);
    [pool release];
    return FALSE;
}
