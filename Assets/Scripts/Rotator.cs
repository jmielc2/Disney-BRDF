using UnityEngine;

public class Rotator : MonoBehaviour {
    [SerializeField, Range(0f, 50f)] private float rotationSpeed = 10f;
    [SerializeField] private bool clockwise = false;
    [SerializeField] private bool play = true;
    
    void Update()
    {
        var rotation = (play ? Time.deltaTime * rotationSpeed * (clockwise ? 1f : -1f) : 0f);
        transform.rotation *= Quaternion.Euler(0f, rotation, 0f);
    }
}
