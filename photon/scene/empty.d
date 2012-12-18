module photon.scene.empty;

private
{
    import dlib.math.vector;
    import photon.scene.scenenode;
    import photon.geometry.aabb;
    import photon.geometry.bsphere;
}

final class Empty: SceneNode
{
    bool boxVisible = false;
    float bsphereRadius = 1.0f;
    Vector3f bboxSize;

    this(SceneNode par = null)
    {
        super(par);
        bboxSize = Vector3f(1.0f, 1.0f, 1.0f);
    }

    override @property BSphere boundingSphere()
    {
        return BSphere(absolutePosition, bsphereRadius);
    }

    override @property AABB boundingBox() // override me
    {
        return AABB(absolutePosition, bboxSize);
    }
/*
    override @property OBB orientedBoundingBox()
    {
        return OBB(absolutePosition, rotation, bboxSize);
    }
*/

    override void render(double delta)
    {
        if (boxVisible)
            AABB(position, bboxSize).draw();
    }
}


