//
//	Copyright (c) 2008-2010, AppReviews
//	http://github.com/gambcl/AppReviews
//	http://www.perculasoft.com/appreviews
//	All rights reserved.
//
//	This software is released under the terms of the BSD License.
//	http://www.opensource.org/licenses/bsd-license.php
//
//	Redistribution and use in source and binary forms, with or without modification,
//	are permitted provided that the following conditions are met:
//
//	* Redistributions of source code must retain the above copyright notice, this
//	  list of conditions and the following disclaimer.
//	* Redistributions in binary form must reproduce the above copyright notice,
//	  this list of conditions and the following disclaimer
//	  in the documentation and/or other materials provided with the distribution.
//	* Neither the name of AppReviews nor the names of its contributors may be used
//	  to endorse or promote products derived from this software without specific
//	  prior written permission.
//
//	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
//	ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
//	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
//	IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
//	INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
//	BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//	DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
//	LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
//	OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
//	OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import "ARAppStoreApplicationReview.h"
#import "FMDatabase.h"
#import "PSLog.h"


@interface ARAppStoreApplicationReview ()

@property (nonatomic, retain) FMDatabase *database;

@end


@implementation ARAppStoreApplicationReview

@synthesize appIdentifier, storeIdentifier, index, reviewer, rating, summary, detail, appVersion, reviewDate, primaryKey, database;

- (id)init
{
	return [self initWithAppIdentifier:nil storeIdentifier:nil];
}

- (id)initWithAppIdentifier:(NSString *)inAppIdentifier storeIdentifier:(NSString *)inStoreIdentifier
{
	if (self = [super init])
	{
		self.appIdentifier = inAppIdentifier;
		self.storeIdentifier = inStoreIdentifier;
		self.index = 0;
		self.reviewer = nil;
		self.rating = 0.0;
		self.summary = nil;
		self.detail = nil;
		self.appVersion = nil;
		self.reviewDate = nil;
		self.database = nil;
	}
	return self;
}

- (void)dealloc
{
	[appIdentifier release];
	[storeIdentifier release];
	[reviewer release];
	[summary release];
	[detail release];
	[appVersion release];
	[reviewDate release];
	[database release];
	[super dealloc];
}

// Creates the object with primary key and non-hydration members are brought into memory.
- (id)initWithPrimaryKey:(NSInteger)pk database:(FMDatabase *)db
{
    if (self = [super init])
	{
        primaryKey = pk;
        self.database = db;

		FMResultSet *row = [db executeQuery:@"SELECT app_identifier, store_identifier, review_index, rating FROM application_review WHERE id=?", [NSNumber numberWithInteger:pk]];
		if (row && [row next])
		{
			self.appIdentifier = [row stringForColumnIndex:0];
			self.storeIdentifier = [row stringForColumnIndex:1];
			self.index = [row intForColumnIndex:2];
			self.rating = [row doubleForColumnIndex:3];
		}
		else
		{
			PSLogError(@"Failed to populate ARAppStoreApplicationReview using primary key %d", pk);
			self.appIdentifier = nil;
			self.storeIdentifier = nil;
			self.index = 0;
			self.rating = 0;
		}
		[row close];
        dirty = NO;
		hydrated = NO;
    }
    return self;
}

// Inserts the object into the database and stores its primary key.
- (void)insertIntoDatabase:(FMDatabase *)db
{
	self.database = db;

	if ([db executeUpdate:@"INSERT INTO application_review (app_identifier, store_identifier, review_index, rating, reviewer, summary, detail, app_version, review_date) VALUES (?,?,?,?,?,?,?,?,?)",
		 appIdentifier,
		 storeIdentifier,
		 [NSNumber numberWithInteger:index],
		 [NSNumber numberWithDouble:rating],
		 reviewer,
		 summary,
		 detail,
		 appVersion,
		 reviewDate])
	{
		primaryKey = [db lastInsertRowId];
	}
	else
	{
		NSString *format = @"Failed to insert ARAppStoreApplicationReview into the database with message '%@'.";
		PSLogError(format, [db lastErrorMessage]);
		NSAssert1(0, format, [db lastErrorMessage]);
	}

    // All data for the application is already in memory, but has not been written to the database.
    // Mark as hydrated to prevent empty/default values from overwriting what is in memory.
    hydrated = YES;
}

// Write any changes to the database.
- (void)save
{
    if (dirty)
	{
		if (![database executeUpdate:@"UPDATE application_review SET app_identifier=?, store_identifier=?, review_index=?, rating=?, reviewer=?, summary=?, detail=?, app_version=?, review_date=? WHERE id=?",
			  appIdentifier,
			  storeIdentifier,
			  [NSNumber numberWithInteger:index],
			  [NSNumber numberWithDouble:rating],
			  reviewer,
			  summary,
			  detail,
			  appVersion,
			  reviewDate,
			  [NSNumber numberWithInteger:primaryKey]])
		{
			NSString *format = @"Failed to save ARAppStoreApplicationReview with message '%@'.";
			PSLogError(format, [database lastErrorMessage]);
			NSAssert1(0, format, [database lastErrorMessage]);
		}

        // Update the object state with respect to unwritten changes.
        dirty = NO;
    }
}

// Brings the rest of the object data into memory. If already in memory, no action is taken (harmless no-op).
- (void)hydrate
{
    // Check if action is necessary.
    if (hydrated)
		return;

	FMResultSet *row = [database executeQuery:@"SELECT reviewer, summary, detail, app_version, review_date FROM application_review WHERE id=?", [NSNumber numberWithInteger:primaryKey]];
	if (row && [row next])
	{
		self.reviewer = [row stringForColumnIndex:0];
		self.summary = [row stringForColumnIndex:1];
		self.detail = [row stringForColumnIndex:2];
		self.appVersion = [row stringForColumnIndex:3];
		self.reviewDate = [row stringForColumnIndex:4];
	}
	else
	{
		PSLogError(@"Failed to hydrate ARAppStoreApplicationReview using primary key %d", primaryKey);
		self.reviewer = nil;
		self.summary = nil;
		self.detail = nil;
		self.appVersion = nil;
		self.reviewDate = nil;
	}
	[row close];

    // Update object state with respect to hydration.
    hydrated = YES;
}

// Flushes all but the primary key and non-hydration members out to the database.
- (void)dehydrate
{
	// Write any changes to the database.
	[self save];

    // Release member variables to reclaim memory. Set to nil to avoid over-releasing them
    // if dehydrate is called multiple times.
	[reviewer release];
	reviewer = nil;
	[summary release];
	summary = nil;
	[detail release];
	detail = nil;
	[appVersion release];
	appVersion = nil;
	[reviewDate release];
	reviewDate = nil;
    // Update the object state with respect to hydration.
    hydrated = NO;
}

// Remove the object completely from the database. In memory deletion to follow...
- (void)deleteFromDatabase
{
	if (![database executeUpdate:@"DELETE FROM application_review WHERE id=?", [NSNumber numberWithInteger:primaryKey]])
	{
		NSString *format = @"Failed to delete ARAppStoreApplicationReview with message '%@'.";
		PSLogError(format, [database lastErrorMessage]);
		NSAssert1(0, format, [database lastErrorMessage]);
	}
}


#pragma mark -
#pragma mark Accessors

// Accessors implemented below. All the "get" accessors simply return the value directly, with no additional
// logic or steps for synchronization. The "set" accessors attempt to verify that the new value is definitely
// different from the old value, to minimize the amount of work done. Any "set" which actually results in changing
// data will mark the object as "dirty" - i.e., possessing data that has not been written to the database.
// All the "set" accessors copy data, rather than retain it. This is common for value objects - strings, numbers,
// dates, data buffers, etc. This ensures that subsequent changes to either the original or the copy don't violate
// the encapsulation of the owning object.

- (void)setAppIdentifier:(NSString *)aString
{
	if ((!appIdentifier && !aString) || (appIdentifier && aString && [appIdentifier isEqualToString:aString]))
		return;

	dirty = YES;
	[appIdentifier release];
	appIdentifier = [aString copy];
}

- (void)setStoreIdentifier:(NSString *)aString
{
	if ((!storeIdentifier && !aString) || (storeIdentifier && aString && [storeIdentifier isEqualToString:aString]))
		return;

	dirty = YES;
	[storeIdentifier release];
	storeIdentifier = [aString copy];
}

- (void)setIndex:(NSUInteger)anInt
{
	if (index == anInt)
		return;

	dirty = YES;
	index = anInt;
}

- (void)setRating:(double)aDouble
{
	dirty = YES;
	rating = aDouble;
}

- (void)setReviewer:(NSString *)aString
{
	if ((!reviewer && !aString) || (reviewer && aString && [reviewer isEqualToString:aString]))
		return;

	dirty = YES;
	[reviewer release];
	reviewer = [aString copy];
}

- (void)setSummary:(NSString *)aString
{
	if ((!summary && !aString) || (summary && aString && [summary isEqualToString:aString]))
		return;

	dirty = YES;
	[summary release];
	summary = [aString copy];
}

- (void)setDetail:(NSString *)aString
{
	if ((!detail && !aString) || (detail && aString && [detail isEqualToString:aString]))
		return;

	dirty = YES;
	[detail release];
	detail = [aString copy];
}

- (void)setAppVersion:(NSString *)aString
{
	if ((!appVersion && !aString) || (appVersion && aString && [appVersion isEqualToString:aString]))
		return;

	dirty = YES;
	[appVersion release];
	appVersion = [aString copy];
}

- (void)setReviewDate:(NSString *)aString
{
	if ((!reviewDate && !aString) || (reviewDate && aString && [reviewDate isEqualToString:aString]))
		return;

	dirty = YES;
	[reviewDate release];
	reviewDate = [aString copy];
}

@end
