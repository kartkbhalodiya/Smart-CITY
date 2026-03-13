# Vercel Free Tier Performance Optimization Guide

## Changes Made for Speed

### 1. Database Optimization
- ✅ Reduced connection timeout from 20s to 5s
- ✅ Added statement timeout (10s) to prevent long queries
- ✅ Simplified database URL parsing (removed complex regex)
- ✅ Using `select_related()` and `only()` for efficient queries
- ✅ Using aggregation instead of multiple count() queries

### 2. Session Optimization
- ✅ Changed `SESSION_SAVE_EVERY_REQUEST` from True to False
- ✅ Fixed session age (was 9999909600, now 1209600)
- ✅ Reduced unnecessary session writes

### 3. Caching
- ✅ Added local memory cache for frequently accessed data
- ✅ 5-minute cache timeout for optimal performance

### 4. Query Optimization
- ✅ User dashboard now uses single aggregation query instead of 4 separate queries
- ✅ Added `only()` to fetch only required fields
- ✅ Proper use of `select_related()` for foreign keys

## Additional Recommendations

### 5. Use Vercel Edge Caching
Add to your `vercel.json`:
```json
{
  "headers": [
    {
      "source": "/static/(.*)",
      "headers": [
        {
          "key": "Cache-Control",
          "value": "public, max-age=31536000, immutable"
        }
      ]
    }
  ]
}
```

### 6. Optimize Heavy Views
For views with many database queries, consider:
- Using `prefetch_related()` for reverse foreign keys
- Implementing pagination (limit to 20-50 items per page)
- Adding database indexes on frequently queried fields

### 7. Database Indexes (Run migrations)
Add indexes to your models:
```python
class Complaint(models.Model):
    # ... existing fields ...
    
    class Meta:
        indexes = [
            models.Index(fields=['user', '-created_at']),
            models.Index(fields=['work_status']),
            models.Index(fields=['complaint_type']),
            models.Index(fields=['assigned_department', '-created_at']),
        ]
```

### 8. Reduce Cold Start Time
- ✅ Already using `.vercelignore` to exclude unnecessary files
- Keep requirements.txt minimal
- Consider lazy loading heavy imports

### 9. Monitor Performance
Check Vercel logs for:
- Database query times
- Function execution duration
- Cold start frequency

### 10. Upgrade Considerations
If still slow on free tier:
- **Vercel Pro**: Faster functions, no cold starts
- **Supabase Pro**: Connection pooling, better performance
- **Redis Cache**: For distributed caching (requires paid plan)

## Quick Wins Applied ✅
1. Database timeout: 20s → 5s
2. Session writes: Every request → Only when changed
3. Query optimization: 4 queries → 1 aggregation
4. Added local memory cache
5. Optimized .vercelignore

## Expected Improvements
- **Initial load**: 30-50% faster
- **Dashboard**: 40-60% faster (fewer DB queries)
- **Subsequent requests**: 20-30% faster (caching)

## Testing
After deployment, test with:
```bash
# Check response time
curl -w "@curl-format.txt" -o /dev/null -s https://your-app.vercel.app/

# curl-format.txt content:
time_namelookup:  %{time_namelookup}s
time_connect:  %{time_connect}s
time_starttransfer:  %{time_starttransfer}s
time_total:  %{time_total}s
```

## Notes
- Vercel free tier has 10s function timeout
- Cold starts add 1-3s on first request
- Database is in AWS Tokyo (check if closer region available)
