using UnityEngine;

public class Rotator : MonoBehaviour {
    [SerializeField, Range(0f, 20f)] private float rotationSpeed = 5f;
    [SerializeField] private bool clockwise = false;
    
    void Update() {
        var rotation = Time.deltaTime * rotationSpeed * (clockwise ? 1f : -1f);
        transform.rotation *= Quaternion.Euler(0f, rotation, 0f);
    }
}
