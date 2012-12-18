module photon.geometry.polyline;

private
{
    import dlib.math.vector;
}

alias Vector2f Point;

/*  
 * Return -1 if x < 0, else return 1
 */
int sign(T) (T x)
{
    return (x < 0 ? -1 : 1);
}

/*
 * Test if p2 is left or right of the (infinite) line (p0, p1)
 */
int isLeft(Point p0, Point p1, Point p2)
{
    float sorting = (p1.x - p0.x) * (p2.y - p0.y)
                  - (p2.x - p0.x) * (p1.y - p0.y);

    if (sorting > 0)
        return 1;
    else if (sorting < 0)
        return -1; 
    else
        return 0;
}

/*
 * Test if the points given forms a clockwise polygon
 */
bool polyIsClockwise(Point[] points)
{
    float a = 0.0f;
    int j = 0;

    foreach(i, v; points)
    {
        j = i + 1;
        if (j == points.length)
            j = 0;
        a += points[i].x * points[j].y - points[i].y * points[j].x;
    }

    return (a <= 0);
}

/*
 * Test if a polygon is convex or not
 */
bool polyIsConvex(Point[] points)
{       if (points.length < 3)
        return false;

    Point p0 = points[0];
    Point p1 = points[1];
    Point p2 = points[2];

    float xc = 0.0f, yc = 0.0f;

    int isSameWinding = isLeft(p0, p1, p2);

    foreach(p; points[2..$]) 
    {
        if (isSameWinding != isLeft(p0, p1, p))
            return false;

        Point a, b;

        a.x = p1.x - p0.x;
        a.y = p1.y - p0.y;
        b.x = p.x - p1.x;
        b.y = p.y - p1.y;

        if (a.x.sign != b.x.sign)
            xc += 1.0f;

        if (a.y.sign != b.y.sign)
            yc += 1.0f;

        p0 = p1;
        p1 = p;
    }
 
    return ((xc <= 2.0f) && (yc <= 2.0f));
}

/*
 * Calculate the area of a polygon  
 */
float polyCalcArea(Point[] points)
{
    if (points.length < 3)
        return 0;

    Point p1 = points[0];
    float a = 0;

    foreach (p2; points[1..$])
    {       
        a += p1.x * p2.y - p2.x * p1.y;
        p1 = p2;
    }

    return (a * 0.5f);
}

/*
 * Calculate the center of a polygon
 */
Point polyCalcCenter(Point[] points)
{   
    assert (points.length > 0);

    float area = polyCalcArea(points);
    Point p1 = points[0];
    float cx = 0, cy = 0;

    foreach (p2; points[1..$])
    {
        float tmp = (p1.x * p2.y - p2.x * p1.y); 
        cx += (p1.x + p2.x) * tmp;
        cy += (p1.y + p2.y) * tmp;
        p1 = p2;
    }

    Point c;
    c.x = 1.0 / (6.0 * area) * cx;
    c.y = 1.0 / (6.0 * area) * cy;
    return c;
}

/*
 * Rearranges vertices around the center
 */
void polyVerticesAroundCenter(ref Point[] points)
{
    Point c = polyCalcCenter(points);
    foreach (ref p; points)
    {
        p.x = p.x - c.x;
        p.y = p.y - c.y;
    }
}

/*
 * Remove close points to simplify a polyline
 * tolerance - the min distance between two points squared
 */
Point[] polyReduce(Point[] points, float tolerance = 0.5f)
{
    assert (points.length > 0);

    enum sqr = (float x) => x*x;
	
    Point curr_p = points[0];
    Point[] reduced;
    reduced ~= points[0];

    foreach (p; points[1..$])
    {
        float distance = sqr(curr_p.x - p.x) + sqr(curr_p.y - p.y);
        if (distance > tolerance)
        {
            curr_p = p;
            reduced ~= p;
        }
    }
    return reduced;
}

