namespace FnBackend.Models;

public class WhoAmIResponseModel
{
    public Guid UserId { get; set; }
    public Guid BusinessUnitId { get; set; }
    public Guid OrganizationId { get; set; }
}
