namespace GhostFinder
{
    bool IsReady()
    {
        return Done;
    }

    int GetTimeForMap(int MapNumber)
    {
        if (!Done) return -1;
        string MapUID = Final[MapNumber - 1];
        for (uint i = 0; i < Matches.Length; i++)
        {
            if (Matches[i].MapUID == MapUID)
            {
                return Matches[i].GhostTimeInt;
            }
        }
        return -1;
    }
}